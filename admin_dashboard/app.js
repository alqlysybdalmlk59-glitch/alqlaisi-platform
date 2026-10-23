(() => {
  const $ = (selector) => document.querySelector(selector);
  const state = { token: sessionStorage.getItem("alq_admin_token") || "", base: $("#apiBase")?.value || "http://localhost:8000/api", user: null, page: "overview", vendors: [], products: [], orders: [], users: [], tickets: [] };
  const pageTitles = {overview:"نظرة عامة",stores:"المتاجر والبائعون",products:"المنتجات والمراجعة",orders:"الطلبات والتوصيل",users:"المستخدمون",support:"الدعم والشكاوى",settings:"الإعدادات والاتصال"};
  const content = $("#pageContent");

  function notify(message, bad = false) {
    const box = $("#notice");
    box.textContent = message;
    box.classList.remove("hidden", "bad");
    if (bad) box.classList.add("bad");
    window.setTimeout(() => box.classList.add("hidden"), 5000);
  }
  function baseUrl() { return ($("#apiBase").value || state.base).trim().replace(/\/+$/, ""); }
  async function api(path, options = {}) {
    const headers = { Accept: "application/json", ...(options.body ? {"Content-Type":"application/json"} : {}), ...(state.token ? {Authorization:"Bearer " + state.token} : {}), ...(options.headers || {}) };
    let response;
    try {
      response = await fetch(baseUrl() + path, { method: options.method || "GET", headers, body: options.body ? JSON.stringify(options.body) : undefined });
    } catch (_) { throw new Error("تعذر الاتصال بالخادم. تأكد أن FastAPI يعمل وأن عنوان API صحيح."); }
    let payload = null;
    try { payload = await response.json(); } catch (_) {}
    if (!response.ok) throw new Error(payload?.detail || payload?.message || ("فشل الطلب: " + response.status));
    return payload;
  }
  function element(tag, className, text) {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = String(text);
    return node;
  }
  function action(label, className, handler) {
    const button = element("button", className, label);
    button.type = "button";
    button.addEventListener("click", async () => {
      button.disabled = true;
      try { await handler(); } catch (error) { notify(error.message || "فشلت العملية.", true); }
      finally { button.disabled = false; }
    });
    return button;
  }
  function badge(text) {
    const cls = text === "مفعل" || text === "منشور" || text === "تم التسليم" || text === "active" ? "good" :
      (text === "مرفوض" || text === "ملغي" || text === "suspended" ? "badge-red" : "pending");
    return element("span", "badge " + cls, text || "غير محدد");
  }
  function record(title, description, status, actions = []) {
    const card = element("article", "record");
    const main = element("div");
    const h = element("h3", "", title);
    if (status) h.append(badge(status));
    main.append(h);
    (description || []).forEach(line => main.append(element("p", "", line)));
    card.append(main);
    const controls = element("div", "record-actions");
    actions.forEach(item => controls.append(item));
    card.append(controls);
    return card;
  }
  function setContent(node) { content.replaceChildren(node); }
  function listOrEmpty(items, emptyMessage) {
    if (!items.length) return element("div", "empty", emptyMessage);
    const list = element("div", "record-list");
    items.forEach(item => list.append(item));
    return list;
  }
  function panel(title, subtitle) {
    const p = element("section", "panel");
    p.append(element("h2", "", title));
    if (subtitle) p.append(element("p", "muted", subtitle));
    return p;
  }
  async function refreshData() {
    const tasks = [
      api("/vendors/"), api("/products/admin/review?status=all"), api("/orders/"),
      api("/users/"), api("/support/")
    ];
    const results = await Promise.allSettled(tasks);
    const names = ["vendors","products","orders","users","tickets"];
    const failed = [];
    results.forEach((result, index) => {
      if (result.status === "fulfilled") state[names[index]] = Array.isArray(result.value) ? result.value : [];
      else { state[names[index]] = []; failed.push(names[index]); }
    });
    renderPage();
    if (failed.length) notify("تعذر تحميل بعض الأقسام: " + failed.join("، ") + " — تحقق من مسارات API وصلاحيات المدير.", true);
  }
  function renderOverview() {
    const wrap = element("div");
    const grid = element("div", "metric-grid");
    [
      ["المتاجر", state.vendors.length],
      ["منتجات قيد المراجعة", state.products.filter(p => p.review_status === "قيد المراجعة").length],
      ["الطلبات", state.orders.length],
      ["تذاكر الدعم", state.tickets.filter(t => t.status === "مفتوحة").length]
    ].forEach(([label, value]) => {
      const m = element("article", "metric");
      m.append(element("p", "", label), element("strong", "", value));
      grid.append(m);
    });
    wrap.append(grid);
    const p = panel("تحتاج إلى متابعة", "هذه الأعداد مستمدة من بيانات API التي أعادها الخادم.");
    p.append(element("p", "muted", "راجع طلبات المتاجر الجديدة والمنتجات المعلقة، ثم تابع الطلبات التي تحتاج إلى تغيير الحالة."));
    p.append(action("مراجعة المتاجر", "secondary", async () => showPage("stores")));
    p.append(action("مراجعة المنتجات", "secondary", async () => showPage("products")));
    wrap.append(p);
    setContent(wrap);
  }
  function renderStores() {
    const wrap = element("div");
    const toolbar = element("div", "toolbar");
    toolbar.append(element("p", "muted", "تُربط المتاجر بحساب واحد فقط. يتطلب الربط الإداري لمتجر قديم ملاحظة توثّق طريقة التحقق، ويُسجَّل كل إجراء في سجل الملكية."));
    const list = [];
    state.vendors.forEach(store => {
      const actions = [];
      if (!store.owner_user_id && store.status !== "مفعل") {
        actions.push(action("ربط حساب المالك", "secondary", async () => {
          const userId = prompt("أدخل معرّف حساب العميل الذي تم التحقق من هويته:");
          if (userId === null || !userId.trim()) return;
          const verificationNote = prompt("اكتب ملاحظة توثيقية (10 أحرف على الأقل) تشرح كيفية التحقق من ملكية المتجر:");
          if (verificationNote === null || verificationNote.trim().length < 10) throw new Error("يلزم إدخال ملاحظة توثيقية واضحة قبل ربط المالك.");
          await api("/vendors/" + encodeURIComponent(store.id) + "/owner", {
            method: "PUT", body: {user_id: userId.trim(), verification_note: verificationNote.trim()}
          });
          notify("تم ربط حساب المالك وتسجيل سبب التحقق في سجل الملكية.");
          await refreshData();
        }));
      }
      if (store.status === "قيد المراجعة" && store.owner_user_id) {
        actions.push(action("اعتماد المتجر", "primary", async () => {
          await api("/vendors/" + encodeURIComponent(store.id) + "/approve", {method:"PUT"});
          notify("تم اعتماد المتجر وربط الحساب.");
          await refreshData();
        }));
        actions.push(action("رفض طلب المتجر", "danger", async () => {
          const reason = prompt("سبب الرفض (سيُحفظ في سجل الملكية):");
          if (reason === null || !reason.trim()) return;
          await api("/vendors/" + encodeURIComponent(store.id) + "/reject?reason=" + encodeURIComponent(reason.trim()), {method:"PUT"});
          notify("تم رفض المتجر وتوثيق السبب.");
          await refreshData();
        }));
      } else if (store.status === "مفعل") {
        actions.push(action("إيقاف مؤقت", "danger", async () => {
          if (!window.confirm("سيوقف هذا المتجر مؤقتاً ويمنع ظهور منتجاته والشراء منها مع الاحتفاظ برابط الملكية. هل تتابع؟")) return;
          await api("/vendors/" + encodeURIComponent(store.id) + "/suspend", {method:"PUT"});
          notify("تم إيقاف المتجر مؤقتاً مع الاحتفاظ بالمالك وسجل الملكية.");
          await refreshData();
        }));
      } else if (store.status === "موقوف") {
        actions.push(action("إعادة تفعيل المتجر", "primary", async () => {
          await api("/vendors/" + encodeURIComponent(store.id) + "/restore", {method:"PUT"});
          notify("تمت إعادة تفعيل المتجر.");
          await refreshData();
        }));
        actions.push(action("رفض المتجر", "danger", async () => {
          const reason = prompt("سبب الرفض (سيُحفظ في سجل الملكية):");
          if (reason === null || !reason.trim()) return;
          await api("/vendors/" + encodeURIComponent(store.id) + "/reject?reason=" + encodeURIComponent(reason.trim()), {method:"PUT"});
          notify("تم رفض المتجر وتوثيق السبب.");
          await refreshData();
        }));
      }
      actions.push(action("سجل الملكية", "secondary", async () => {
        const history = await api("/vendors/" + encodeURIComponent(store.id) + "/ownership-history");
        if (!Array.isArray(history) || history.length === 0) { window.alert("لا توجد إجراءات موثقة لهذا المتجر."); return; }
        window.alert(history.map(event =>
          (event.created_at || "") + " | " + (event.action || "") +
          " | المنفذ: " + (event.actor_user_id || "—") +
          " | المالك السابق: " + (event.previous_owner_user_id || "—") +
          " | المالك الجديد: " + (event.new_owner_user_id || "—") +
          " | التوثيق: " + (event.verification_note || "")
        ).join("\\n\\n"));
      }));
      const feeInput = element("input", "");
      feeInput.type = "number"; feeInput.min = "0"; feeInput.step = "0.01";
      feeInput.value = String(store.delivery_fee ?? 15);
      feeInput.setAttribute("aria-label", "رسوم توصيل " + store.store_name);
      const feeSave = action("حفظ الرسم", "secondary", async () => {
        const fee = Number(feeInput.value);
        if (!Number.isFinite(fee) || fee < 0) throw new Error("أدخل رسماً صحيحاً.");
        await api("/vendors/" + encodeURIComponent(store.id) + "/delivery-fee", {method:"PUT",body:{delivery_fee:fee}});
        notify("تم تحديث رسوم توصيل المتجر.");
        await refreshData();
      });
      const fee = element("div", "inline-field");
      fee.append(feeInput, feeSave);
      list.push(record(store.store_name, [
        "المالك: " + (store.owner_name || "—"),
        "معرّف المالك: " + (store.owner_user_id || "غير مربوط"),
        "الهاتف: " + (store.phone || "—"),
        "المعرّف: " + store.id,
      ], store.status, actions.concat([fee])));
    });
    wrap.append(toolbar, listOrEmpty(list, "لا توجد متاجر مسجلة حتى الآن."));
    setContent(wrap);
  }
  function renderProducts() {
    const wrap = element("div");
    const toolbar = element("div", "toolbar");
    toolbar.append(element("p", "muted", "لا يُنشر المنتج إلا بعد تحديد سعر البيع من الإدارة. يبدأ المنتج الجديد غير متاح."));
    const filter = element("select");
    [["all","كل المنتجات"],["قيد المراجعة","قيد المراجعة"],["منشور","منشورة"],["مرفوض","مرفوضة"]].forEach(([v,t]) => { const o=element("option","",t); o.value=v; filter.append(o); });
    filter.value = "all";
    filter.addEventListener("change", async () => {
      state.products = await api("/products/admin/review?status=" + encodeURIComponent(filter.value));
      renderProducts();
    });
    toolbar.append(filter);
    const list = [];
    state.products.forEach(product => {
      const actions = [];
      if (product.review_status === "قيد المراجعة") {
        actions.push(action("تحديد السعر واعتماد", "primary", async () => {
          const raw = prompt("أدخل سعر البيع المعتمد بالريال اليمني:", product.price > 0 ? product.price : "");
          if (raw === null) return;
          const price = Number(raw);
          if (!Number.isFinite(price) || price <= 0) throw new Error("السعر يجب أن يكون رقماً أكبر من صفر.");
          await api("/products/" + encodeURIComponent(product.id) + "/approve", {method:"PUT",body:{sale_price:price,approved:true,admin_notes:""}});
          notify("تم اعتماد المنتج بالسعر المحدد.");
          await refreshData();
        }));
        actions.push(action("رفض المنتج", "danger", async () => {
          const notes = prompt("سبب الرفض (اختياري):") || "";
          await api("/products/" + encodeURIComponent(product.id) + "/reject?notes=" + encodeURIComponent(notes), {method:"PUT"});
          notify("تم رفض المنتج.");
          await refreshData();
        }));
      }
      list.push(record(product.title, ["المتجر: " + (product.vendor_name || product.vendor_id), "السعر: " + (product.price ?? 0) + " ريال", "التوفر: " + (product.is_available ? "متاح" : "غير متاح"), "المعرف: " + product.id], product.review_status, actions));
    });
    wrap.append(toolbar, listOrEmpty(list, "لا توجد منتجات في هذا التصنيف."));
    setContent(wrap);
  }
  function renderOrders() {
    const wrap = element("div");
    wrap.append(element("p", "muted", "الطلب من عدة متاجر يُحفظ كطلبات منفصلة. بعد تجهيز الطلب، تُسند الإدارة موظف التوصيل الداخلي قبل تحويله إلى قيد التوصيل؛ الدفع عند الاستلام."));
    const allowedStatusOptions = {
      "بانتظار القبول": ["بانتظار القبول", "قيد التجهيز", "ملغي"],
      "قيد التجهيز": ["قيد التجهيز", "جاهز للتوصيل", "ملغي"],
      "جاهز للتوصيل": ["جاهز للتوصيل", "ملغي"],
      "قيد التوصيل": ["قيد التوصيل", "تم التسليم"],
      "تم التسليم": ["تم التسليم"],
      "ملغي": ["ملغي"]
    };
    const list = [];
    state.orders.forEach(order => {
      const statuses = allowedStatusOptions[order.status] || [order.status];
      const select = element("select");
      statuses.forEach(s => { const o=element("option","",s); o.value=s; select.append(o); });
      select.value = order.status;
      const save = action("حفظ الحالة", "secondary", async () => {
        await api("/orders/" + encodeURIComponent(order.id) + "/status?status=" + encodeURIComponent(select.value), {method:"PUT"});
        notify("تم تحديث حالة الطلب.");
        await refreshData();
      });
      const actions = [select, save];
      if (order.status === "جاهز للتوصيل" || order.status === "قيد التوصيل") {
        actions.push(action(order.status === "قيد التوصيل" ? "إعادة إسناد موظف التوصيل" : "إسناد موظف التوصيل", "primary", async () => {
          const name = prompt("اسم موظف التوصيل الداخلي:", order.delivery_agent_name || "");
          if (name === null) return;
          if (name.trim().length < 2) throw new Error("اكتب اسم موظف التوصيل.");
          const phone = prompt("رقم هاتف موظف التوصيل:", order.delivery_agent_phone || "");
          if (phone === null) return;
          if (!/^[+0-9][0-9 ()-]{5,18}[0-9]$/.test(phone.trim())) throw new Error("رقم الهاتف غير صالح؛ استخدم 7 إلى 20 محرفاً من الأرقام وعلامات الهاتف.");
          const notes = prompt("ملاحظات التوصيل (اختياري):", order.delivery_notes || "");
          if (notes === null) return;
          await api("/orders/" + encodeURIComponent(order.id) + "/dispatch", {method:"PUT", body:{
            delivery_agent_name: name.trim(), delivery_agent_phone: phone.trim(), delivery_notes: notes.trim()
          }});
          notify("تم تسجيل موظف التوصيل وحفظ الإسناد في سجل الطلب.");
          await refreshData();
        }));
      }
      const history = action("سجل تغييرات الحالة", "secondary", async () => {
        const entries = await api("/orders/" + encodeURIComponent(order.id) + "/history");
        if (!Array.isArray(entries) || entries.length === 0) {
          window.alert("لا يوجد سجل حالة محفوظ لهذا الطلب القديم.");
          return;
        }
        window.alert(entries.map(entry =>
          (entry.old_status || "إنشاء الطلب") + " ← " + entry.new_status +
          "\\n" + entry.created_at + " · " + entry.changed_by_role +
          (entry.note ? " · " + entry.note : "")
        ).join("\\n\\n"));
      });
      actions.push(history);
      list.push(record("طلب " + order.id, ["العميل: " + order.client_name + " · المتجر: " + order.vendor_name,
        "قيمة المنتجات: " + order.items_price + " · التوصيل: " + order.delivery_fee + " · الإجمالي: " + order.total_price + " ريال",
        "طريقة الدفع: " + order.payment_method,
        "موظف التوصيل: " + (order.delivery_agent_name || "لم يتم التعيين") + " · الهاتف: " + (order.delivery_agent_phone || "—"),
        "ملاحظات التوصيل: " + (order.delivery_notes || "—"),
        "تاريخ الإسناد: " + (order.delivery_assigned_at || "—") + " · تاريخ التسليم: " + (order.delivery_delivered_at || "—"),
        "تاريخ الإنشاء: " + order.date], order.status, actions));
    });
    wrap.append(listOrEmpty(list, "لا توجد طلبات بعد."));
    setContent(wrap);
  }
  function renderUsers() {
    const rows = state.users.map(user => {
      const actions = [];
      const role = String(user.role || "").toUpperCase();
      const status = String(user.status || "active");
      const isCurrentAdmin = role === "ADMIN" && state.user &&
        String(state.user.id) === String(user.id);

      if (!isCurrentAdmin) {
        const nextStatus = status === "suspended" ? "active" : "suspended";
        actions.push(action(
          nextStatus === "active" ? "إعادة تفعيل الحساب" : "إيقاف الحساب",
          nextStatus === "active" ? "secondary" : "danger",
          async () => {
            const confirmed = window.confirm(
              nextStatus === "suspended"
                ? "سيُمنع هذا الحساب من استخدام عمليات المنصة. هل تريد إيقافه؟"
                : "هل تريد إعادة تفعيل هذا الحساب؟"
            );
            if (!confirmed) return;
            await api("/users/" + encodeURIComponent(user.id) + "/status", {
              method: "PUT",
              body: {status: nextStatus}
            });
            notify(nextStatus === "active" ? "تم تفعيل الحساب." : "تم إيقاف الحساب.");
            await refreshData();
          }
        ));
      }

      return record(
        user.name || user.full_name || user.id,
        [
          "الهاتف: " + (user.phone || "—"),
          "البريد: " + (user.email || "—"),
          "الدور: " + (user.role || "—"),
          "حالة الحساب: " + status,
          "المتجر المرتبط: " + (user.store_id || "—"),
          "المعرف: " + user.id
        ],
        status,
        actions
      );
    });
    setContent(listOrEmpty(rows, "لا توجد حسابات لعرضها أو أن مسار المستخدمين غير متاح لهذا الحساب."));
  }
  function renderSupport() {
    const rows = state.tickets.map(ticket => {
      const actions = [];
      if (ticket.status === "مفتوحة") actions.push(action("الرد وإغلاق التذكرة", "primary", async () => {
        const response = prompt("اكتب الرد الذي سيُرسل لصاحب التذكرة:");
        if (response === null || !response.trim()) return;
        await api("/support/" + encodeURIComponent(ticket.id) + "/respond?response=" + encodeURIComponent(response), {method:"PUT"});
        notify("تم حفظ الرد وإغلاق التذكرة.");
        await refreshData();
      }));
      return record(ticket.subject || "تذكرة دعم", ["المستخدم: " + (ticket.user_name || ticket.user_id), ticket.details || "", "الرد السابق: " + (ticket.response || "لا يوجد")], ticket.status, actions);
    });
    setContent(listOrEmpty(rows, "لا توجد تذاكر دعم."));
  }
  function renderSettings() {
    const wrap = element("div");
    const p = panel("إعدادات الاتصال", "عنوان API يُستخدم في الجلسة الحالية. لا تُدخل أسراراً في هذه الصفحة.");
    const label = element("label", "", "عنوان الخادم");
    const input = element("input"); input.type="url"; input.value=baseUrl(); input.required=true;
    const button = action("اختبار الاتصال وتحديث البيانات", "primary", async () => {
      if (!input.value.trim()) throw new Error("أدخل عنوان API.");
      $("#apiBase").value = input.value.trim().replace(/\/+$/,"");
      state.base = $("#apiBase").value;
      await api("/health");
      notify("الخادم يستجيب.");
      await refreshData();
    });
    label.append(input); p.append(label,button);
    const info = panel("إعدادات التشغيل", "التوثيق والتفاصيل الحساسة تتم على الخادم. اترك إنشاء أدوار الإدارة واعتمادها خارج الواجهة العامة.");
    info.append(element("p","muted","إصدار الواجهة: 1.0 · الدفع: عند الاستلام · التوصيل: تشغيل داخلي يدوي · المخزون: توافر يدوي فقط."));
    wrap.append(p,info); setContent(wrap);
  }
  function renderPage() {
    $("#pageTitle").textContent = pageTitles[state.page] || "إدارة القليسي";
    if (state.page==="overview") renderOverview();
    else if (state.page==="stores") renderStores();
    else if (state.page==="products") renderProducts();
    else if (state.page==="orders") renderOrders();
    else if (state.page==="users") renderUsers();
    else if (state.page==="support") renderSupport();
    else renderSettings();
    document.querySelectorAll(".nav-item").forEach(button => button.classList.toggle("active",button.dataset.page===state.page));
  }
  async function showPage(page) {
    state.page = page;
    renderPage();
    if (state.token) await refreshData();
  }
  async function loadMe() {
    const me = await api("/auth/me");
    if (me.role !== "admin") throw new Error("هذا الحساب ليس حساب إدارة معتمداً.");
    state.user = me;
    $("#adminIdentity").textContent = me.full_name || me.name || me.phone || "مدير النظام";
    $("#loginScreen").classList.add("hidden");
    $("#workspace").classList.remove("hidden");
    await refreshData();
  }
  $("#loginForm").addEventListener("submit", async event => {
    event.preventDefault();
    $("#loginError").textContent = "";
    state.base = baseUrl();
    const submit = event.submitter;
    if (submit) submit.disabled = true;
    try {
      const session = await api("/auth/login",{method:"POST",body:{phone:$("#phone").value.trim(),password:$("#password").value}});
      state.token = session.access_token;
      sessionStorage.setItem("alq_admin_token",state.token);
      await loadMe();
    } catch (error) {
      state.token = ""; sessionStorage.removeItem("alq_admin_token");
      $("#loginError").textContent = error.message || "تعذر تسجيل الدخول.";
    } finally { if (submit) submit.disabled = false; }
  });
  $("#navigation").addEventListener("click", event => {
    const button = event.target.closest("[data-page]");
    if (button) showPage(button.dataset.page).catch(error=>notify(error.message,true));
  });
  $("#refreshButton").addEventListener("click",()=>refreshData().then(()=>notify("تم تحديث البيانات.")).catch(e=>notify(e.message,true)));
  $("#logoutButton").addEventListener("click",()=>{state.token="";state.user=null;sessionStorage.removeItem("alq_admin_token");$("#workspace").classList.add("hidden");$("#loginScreen").classList.remove("hidden");});
  if (state.token) loadMe().catch(error=>{sessionStorage.removeItem("alq_admin_token");state.token="";notify(error.message,true);});
})();