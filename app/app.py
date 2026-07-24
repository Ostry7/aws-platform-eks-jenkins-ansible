### AI GENERATED CODE

from flask import Flask, jsonify, request, render_template_string
from prometheus_flask_exporter import PrometheusMetrics
from prometheus_client import Counter
import psycopg2
import psycopg2.extras
import os
import random

app = Flask(__name__)
metrics = PrometheusMetrics(app)

# ── Prometheus counters ────────────────────────────────────────────────────────
fact_counter   = Counter('fact_requests_total',   'Total number of /fact requests')
health_counter = Counter('health_requests_total', 'Total number of /health requests')
crud_counter   = Counter('crud_operations_total', 'Total CRUD operations', ['table', 'operation'])

# ── DB connection ──────────────────────────────────────────────────────────────
def get_db():
    return psycopg2.connect(
        host     = os.getenv("DB_HOST",     "localhost"),
        port     = os.getenv("DB_PORT",     "5432"),
        dbname   = os.getenv("DB_NAME",     "devops_db"),
        user     = os.getenv("DB_USER",     "postgres"),
        password = os.getenv("DB_PASSWORD", "postgres"),
    )

# ── HTML template ──────────────────────────────────────────────────────────────
HTML = """<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>DevOps Portfolio — DB Manager</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=Syne:wght@400;700;800&display=swap" rel="stylesheet">
<style>
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

  :root {
    --bg:       #0d0f14;
    --surface:  #14171f;
    --border:   #252932;
    --accent:   #00e5c3;
    --accent2:  #ff4d6d;
    --text:     #e2e8f0;
    --muted:    #64748b;
    --radius:   6px;
    --mono:     'IBM Plex Mono', monospace;
    --sans:     'Syne', sans-serif;
  }

  body {
    background: var(--bg);
    color: var(--text);
    font-family: var(--sans);
    min-height: 100vh;
    display: flex;
    flex-direction: column;
  }

  /* ── HEADER ── */
  header {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 18px 32px;
    border-bottom: 1px solid var(--border);
    background: var(--surface);
  }
  .logo {
    font-size: 11px;
    font-family: var(--mono);
    color: var(--accent);
    letter-spacing: .15em;
    text-transform: uppercase;
  }
  .logo span { color: var(--muted); }
  .status-dot {
    width: 8px; height: 8px;
    border-radius: 50%;
    background: var(--accent);
    box-shadow: 0 0 8px var(--accent);
    animation: pulse 2s infinite;
    margin-left: auto;
  }
  @keyframes pulse { 0%,100%{opacity:1} 50%{opacity:.4} }
  .env-badge {
    font-family: var(--mono);
    font-size: 10px;
    padding: 3px 10px;
    border: 1px solid var(--border);
    border-radius: 20px;
    color: var(--muted);
    letter-spacing: .1em;
  }
  .db-badge {
    font-family: var(--mono);
    font-size: 10px;
    padding: 3px 10px;
    border-radius: 20px;
    letter-spacing: .1em;
  }
  .db-badge.primary {
    border: 1px solid rgba(0,229,195,.4);
    color: #00e5c3;
    background: rgba(0,229,195,.08);
  }
  .db-badge.dr {
    border: 1px solid rgba(255,77,109,.4);
    color: #ff4d6d;
    background: rgba(255,77,109,.08);
  }

  /* ── LAYOUT ── */
  .main {
    display: grid;
    grid-template-columns: 1fr 320px;
    gap: 0;
    flex: 1;
    min-height: 0;
  }

  /* ── TABLES PANEL ── */
  .tables-panel {
    padding: 28px 32px;
    overflow-y: auto;
    border-right: 1px solid var(--border);
  }

  .section-label {
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: .2em;
    color: var(--muted);
    text-transform: uppercase;
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .section-label::after {
    content: '';
    flex: 1;
    height: 1px;
    background: var(--border);
  }

  .table-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--radius);
    margin-bottom: 28px;
    overflow: hidden;
  }
  .table-card-header {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 12px 16px;
    border-bottom: 1px solid var(--border);
    background: #1a1e28;
  }
  .table-name {
    font-family: var(--mono);
    font-size: 12px;
    color: var(--accent);
    font-weight: 600;
  }
  .row-count {
    font-family: var(--mono);
    font-size: 10px;
    color: var(--muted);
    margin-left: auto;
  }

  table {
    width: 100%;
    border-collapse: collapse;
    font-family: var(--mono);
    font-size: 12px;
  }
  thead tr {
    background: #11141b;
  }
  th {
    padding: 9px 14px;
    text-align: left;
    color: var(--muted);
    font-size: 10px;
    letter-spacing: .12em;
    text-transform: uppercase;
    border-bottom: 1px solid var(--border);
  }
  td {
    padding: 9px 14px;
    border-bottom: 1px solid #1a1e28;
    color: var(--text);
    vertical-align: middle;
  }
  tr:last-child td { border-bottom: none; }
  tr:hover td { background: rgba(0,229,195,.04); }

  .action-btn {
    cursor: pointer;
    border: none;
    border-radius: 4px;
    font-family: var(--mono);
    font-size: 10px;
    padding: 4px 10px;
    transition: .15s;
    letter-spacing: .05em;
  }
  .btn-edit {
    background: rgba(0,229,195,.1);
    color: var(--accent);
    border: 1px solid rgba(0,229,195,.25);
    margin-right: 4px;
  }
  .btn-edit:hover { background: rgba(0,229,195,.2); }
  .btn-delete {
    background: rgba(255,77,109,.1);
    color: var(--accent2);
    border: 1px solid rgba(255,77,109,.25);
  }
  .btn-delete:hover { background: rgba(255,77,109,.2); }

  /* ── SIDE PANEL ── */
  .side-panel {
    padding: 28px 24px;
    overflow-y: auto;
    background: var(--surface);
  }

  .form-card {
    border: 1px solid var(--border);
    border-radius: var(--radius);
    overflow: hidden;
  }
  .form-tabs {
    display: flex;
    background: #11141b;
    border-bottom: 1px solid var(--border);
  }
  .tab-btn {
    flex: 1;
    padding: 10px;
    background: none;
    border: none;
    font-family: var(--mono);
    font-size: 10px;
    letter-spacing: .1em;
    color: var(--muted);
    cursor: pointer;
    transition: .15s;
    text-transform: uppercase;
    border-bottom: 2px solid transparent;
  }
  .tab-btn.active {
    color: var(--accent);
    border-bottom-color: var(--accent);
    background: rgba(0,229,195,.05);
  }
  .tab-btn:hover:not(.active) { color: var(--text); }

  .form-body { padding: 20px; display: none; }
  .form-body.active { display: block; }

  .field { margin-bottom: 14px; }
  .field label {
    display: block;
    font-family: var(--mono);
    font-size: 10px;
    color: var(--muted);
    letter-spacing: .1em;
    text-transform: uppercase;
    margin-bottom: 6px;
  }
  .field input, .field select {
    width: 100%;
    background: #0d0f14;
    border: 1px solid var(--border);
    border-radius: 4px;
    color: var(--text);
    font-family: var(--mono);
    font-size: 12px;
    padding: 8px 10px;
    outline: none;
    transition: .15s;
  }
  .field input:focus, .field select:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 2px rgba(0,229,195,.1);
  }
  .field select option { background: #0d0f14; }

  .table-selector {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
  }
  .tbl-radio {
    flex: 1;
    padding: 7px;
    background: #0d0f14;
    border: 1px solid var(--border);
    border-radius: 4px;
    font-family: var(--mono);
    font-size: 11px;
    color: var(--muted);
    cursor: pointer;
    text-align: center;
    transition: .15s;
  }
  .tbl-radio.selected {
    border-color: var(--accent);
    color: var(--accent);
    background: rgba(0,229,195,.07);
  }

  .dynamic-fields { min-height: 40px; }

  .submit-btn {
    width: 100%;
    padding: 10px;
    background: var(--accent);
    color: #0d0f14;
    border: none;
    border-radius: 4px;
    font-family: var(--mono);
    font-size: 12px;
    font-weight: 600;
    letter-spacing: .1em;
    cursor: pointer;
    margin-top: 6px;
    transition: .15s;
    text-transform: uppercase;
  }
  .submit-btn:hover { opacity: .85; }
  .submit-btn.danger {
    background: var(--accent2);
  }

  .msg {
    font-family: var(--mono);
    font-size: 11px;
    padding: 8px 10px;
    border-radius: 4px;
    margin-top: 12px;
    display: none;
  }
  .msg.success { background: rgba(0,229,195,.1); color: var(--accent); border: 1px solid rgba(0,229,195,.2); }
  .msg.error   { background: rgba(255,77,109,.1); color: var(--accent2); border: 1px solid rgba(255,77,109,.2); }

  /* scrollbar */
  ::-webkit-scrollbar { width: 5px; height: 5px; }
  ::-webkit-scrollbar-track { background: var(--bg); }
  ::-webkit-scrollbar-thumb { background: var(--border); border-radius: 3px; }
</style>
</head>
<body>

<header>
  <div class="logo">devops<span>/</span>portfolio <span>— db manager</span></div>
  <div class="env-badge">{{ env }}</div>
  <div class="db-badge {{ 'dr' if db_mode == 'DR' else 'primary' }}">
    db: {{ db_mode }}
  </div>
  <div class="status-dot"></div>
</header>

<div class="main">

  <!-- ── TABLES ── -->
  <div class="tables-panel">
    <div class="section-label">tables</div>

    <!-- users -->
    <div class="table-card">
      <div class="table-card-header">
        <span class="table-name">users</span>
        <span class="row-count" id="users-count">{{ users|length }} rows</span>
      </div>
      <table id="users-table">
        <thead>
          <tr><th>id</th><th>name</th><th>email</th><th>role</th><th>actions</th></tr>
        </thead>
        <tbody>
          {% for u in users %}
          <tr id="user-row-{{ u.id }}">
            <td>{{ u.id }}</td>
            <td>{{ u.name }}</td>
            <td>{{ u.email }}</td>
            <td>{{ u.role }}</td>
            <td>
              <button class="action-btn btn-edit"
                onclick="loadEdit('users', {{ u.id }}, {{ u|tojson }})">edit</button>
              <button class="action-btn btn-delete"
                onclick="loadDelete('users', {{ u.id }})">del</button>
            </td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>

    <!-- products -->
    <div class="table-card">
      <div class="table-card-header">
        <span class="table-name">products</span>
        <span class="row-count" id="products-count">{{ products|length }} rows</span>
      </div>
      <table id="products-table">
        <thead>
          <tr><th>id</th><th>name</th><th>price</th><th>category</th><th>actions</th></tr>
        </thead>
        <tbody>
          {% for p in products %}
          <tr id="product-row-{{ p.id }}">
            <td>{{ p.id }}</td>
            <td>{{ p.name }}</td>
            <td>{{ p.price }}</td>
            <td>{{ p.category }}</td>
            <td>
              <button class="action-btn btn-edit"
                onclick="loadEdit('products', {{ p.id }}, {{ p|tojson }})">edit</button>
              <button class="action-btn btn-delete"
                onclick="loadDelete('products', {{ p.id }})">del</button>
            </td>
          </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>
  </div>

  <!-- ── SIDE PANEL ── -->
  <div class="side-panel">
    <div class="section-label">operations</div>
    <div class="form-card">
      <div class="form-tabs">
        <button class="tab-btn active" onclick="switchTab('add')">+ add</button>
        <button class="tab-btn" onclick="switchTab('edit')">✎ edit</button>
        <button class="tab-btn" onclick="switchTab('delete')">✕ delete</button>
      </div>

      <!-- ADD -->
      <div class="form-body active" id="tab-add">
        <div class="table-selector">
          <div class="tbl-radio selected" onclick="selectTable('add','users')" id="add-users">users</div>
          <div class="tbl-radio" onclick="selectTable('add','products')" id="add-products">products</div>
        </div>
        <div class="dynamic-fields" id="add-fields"></div>
        <button class="submit-btn" onclick="submitAdd()">insert record</button>
        <div class="msg" id="add-msg"></div>
      </div>

      <!-- EDIT -->
      <div class="form-body" id="tab-edit">
        <div class="field">
          <label>table / id</label>
          <div style="display:flex;gap:8px">
            <input id="edit-table" placeholder="table" style="width:45%" readonly>
            <input id="edit-id"    placeholder="id"    style="width:55%" readonly>
          </div>
        </div>
        <div class="dynamic-fields" id="edit-fields"></div>
        <button class="submit-btn" onclick="submitEdit()">save changes</button>
        <div class="msg" id="edit-msg"></div>
      </div>

      <!-- DELETE -->
      <div class="form-body" id="tab-delete">
        <div class="field">
          <label>table</label>
          <input id="del-table" readonly>
        </div>
        <div class="field">
          <label>record id</label>
          <input id="del-id" type="number" readonly>
        </div>
        <button class="submit-btn danger" onclick="submitDelete()">delete record</button>
        <div class="msg" id="del-msg"></div>
      </div>
    </div>
  </div>
</div>

<script>
/* ── state ─────────────────────────────────────────────────────────────── */
const schemas = {
  users:    [{k:'name',t:'text'},{k:'email',t:'email'},{k:'role',t:'text'}],
  products: [{k:'name',t:'text'},{k:'price',t:'number'},{k:'category',t:'text'}],
};
let addTable = 'users';

/* ── tabs ── */
function switchTab(name) {
  document.querySelectorAll('.tab-btn').forEach((b,i)=>{
    b.classList.toggle('active', ['add','edit','delete'][i]===name);
  });
  document.querySelectorAll('.form-body').forEach(f=>f.classList.remove('active'));
  document.getElementById('tab-'+name).classList.add('active');
}

/* ── table selector (add) ── */
function selectTable(tab, tbl) {
  addTable = tbl;
  ['users','products'].forEach(t=>{
    document.getElementById(tab+'-'+t).classList.toggle('selected', t===tbl);
  });
  renderFields('add-fields', schemas[tbl], {});
}

/* ── render dynamic fields ── */
function renderFields(containerId, schema, vals) {
  const c = document.getElementById(containerId);
  c.innerHTML = schema.map(f=>`
    <div class="field">
      <label>${f.k}</label>
      <input id="f-${f.k}" type="${f.t}" value="${vals[f.k]??''}" placeholder="${f.k}">
    </div>`).join('');
}

function getFieldVals(schema) {
  const o={};
  schema.forEach(f=>{ o[f.k]=document.getElementById('f-'+f.k)?.value; });
  return o;
}

/* ── load edit ── */
function loadEdit(table, id, row) {
  document.getElementById('edit-table').value = table;
  document.getElementById('edit-id').value    = id;
  renderFields('edit-fields', schemas[table], row);
  switchTab('edit');
}

/* ── load delete ── */
function loadDelete(table, id) {
  document.getElementById('del-table').value = table;
  document.getElementById('del-id').value    = id;
  switchTab('delete');
}

/* ── API calls ── */
async function api(method, path, body) {
  const res = await fetch(path, {
    method,
    headers: {'Content-Type':'application/json'},
    body: body ? JSON.stringify(body) : undefined,
  });
  return res.json();
}

function showMsg(id, ok, text) {
  const el = document.getElementById(id);
  el.style.display='block';
  el.className='msg '+(ok?'success':'error');
  el.textContent = text;
  setTimeout(()=>el.style.display='none', 3500);
}

async function submitAdd() {
  const data = getFieldVals(schemas[addTable]);
  const r = await api('POST', `/api/${addTable}`, data);
  if(r.id) { showMsg('add-msg',true,`Inserted id=${r.id}`); reloadTables(); }
  else       showMsg('add-msg',false, r.error||'Error');
}

async function submitEdit() {
  const table = document.getElementById('edit-table').value;
  const id    = document.getElementById('edit-id').value;
  const data  = getFieldVals(schemas[table]);
  const r = await api('PUT', `/api/${table}/${id}`, data);
  if(r.ok) { showMsg('edit-msg',true,'Updated'); reloadTables(); }
  else       showMsg('edit-msg',false, r.error||'Error');
}

async function submitDelete() {
  const table = document.getElementById('del-table').value;
  const id    = document.getElementById('del-id').value;
  const r = await api('DELETE', `/api/${table}/${id}`);
  if(r.ok) { showMsg('del-msg',true,'Deleted'); reloadTables(); }
  else       showMsg('del-msg',false, r.error||'Error');
}

/* ── reload tables via fetch ── */
async function reloadTables() {
  const data = await api('GET', '/api/data');
  updateTable('users',    data.users,    ['id','name','email','role']);
  updateTable('products', data.products, ['id','name','price','category']);
}

function updateTable(tbl, rows, cols) {
  const tbody = document.querySelector(`#${tbl}-table tbody`);
  tbody.innerHTML = rows.map(r=>`
    <tr id="${tbl}-row-${r.id}">
      ${cols.map(c=>`<td>${r[c]}</td>`).join('')}
      <td>
        <button class="action-btn btn-edit"
          onclick='loadEdit("${tbl}", ${r.id}, ${JSON.stringify(r)})'>edit</button>
        <button class="action-btn btn-delete"
          onclick='loadDelete("${tbl}", ${r.id})'>del</button>
      </td>
    </tr>`).join('');
  document.getElementById(`${tbl}-count`).textContent = rows.length+' rows';
}

/* ── init ── */
renderFields('add-fields', schemas.users, {});
</script>
</body>
</html>
"""

# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    try:
        with get_db() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT * FROM users    ORDER BY id")
                users = cur.fetchall()
                cur.execute("SELECT * FROM products ORDER BY id")
                products = cur.fetchall()
        return render_template_string(HTML,
            users=users, products=products,
            env=os.getenv("ENV", "dev"),
            db_mode=os.getenv("DB_MODE", "PRIMARY"))
    except Exception as e:
        return f"<pre>DB error: {e}</pre>", 500


@app.route("/api/data")
def api_data():
    with get_db() as conn:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute("SELECT * FROM users    ORDER BY id")
            users = cur.fetchall()
            cur.execute("SELECT * FROM products ORDER BY id")
            products = cur.fetchall()
    return jsonify(users=[dict(r) for r in users],
                   products=[dict(r) for r in products])


# ── USERS CRUD ────────────────────────────────────────────────────────────────

@app.route("/api/users", methods=["POST"])
def create_user():
    d = request.json
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO users (name, email, role) VALUES (%s,%s,%s) RETURNING id",
                    (d["name"], d["email"], d.get("role","user"))
                )
                new_id = cur.fetchone()[0]
            conn.commit()
        crud_counter.labels(table="users", operation="insert").inc()
        return jsonify(id=new_id)
    except Exception as e:
        return jsonify(error=str(e)), 400


@app.route("/api/users/<int:uid>", methods=["PUT"])
def update_user(uid):
    d = request.json
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE users SET name=%s, email=%s, role=%s WHERE id=%s",
                    (d["name"], d["email"], d.get("role","user"), uid)
                )
            conn.commit()
        crud_counter.labels(table="users", operation="update").inc()
        return jsonify(ok=True)
    except Exception as e:
        return jsonify(error=str(e)), 400


@app.route("/api/users/<int:uid>", methods=["DELETE"])
def delete_user(uid):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM users WHERE id=%s", (uid,))
        conn.commit()
    crud_counter.labels(table="users", operation="delete").inc()
    return jsonify(ok=True)


# ── PRODUCTS CRUD ─────────────────────────────────────────────────────────────

@app.route("/api/products", methods=["POST"])
def create_product():
    d = request.json
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO products (name, price, category) VALUES (%s,%s,%s) RETURNING id",
                    (d["name"], d["price"], d.get("category","general"))
                )
                new_id = cur.fetchone()[0]
            conn.commit()
        crud_counter.labels(table="products", operation="insert").inc()
        return jsonify(id=new_id)
    except Exception as e:
        return jsonify(error=str(e)), 400


@app.route("/api/products/<int:pid>", methods=["PUT"])
def update_product(pid):
    d = request.json
    try:
        with get_db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE products SET name=%s, price=%s, category=%s WHERE id=%s",
                    (d["name"], d["price"], d.get("category","general"), pid)
                )
            conn.commit()
        crud_counter.labels(table="products", operation="update").inc()
        return jsonify(ok=True)
    except Exception as e:
        return jsonify(error=str(e)), 400


@app.route("/api/products/<int:pid>", methods=["DELETE"])
def delete_product(pid):
    with get_db() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM products WHERE id=%s", (pid,))
        conn.commit()
    crud_counter.labels(table="products", operation="delete").inc()
    return jsonify(ok=True)


# ── Legacy routes (kept from original) ────────────────────────────────────────

@app.route("/health")
def health():
    health_counter.inc()
    return jsonify({"status": "healthy"})


@app.route("/fact")
def fact():
    fact_counter.inc()
    facts = ["DevOps is culture, not just tools.",
             "Automate everything you do more than twice.",
             "Observability: metrics, logs, traces"]
    return jsonify({"fact": random.choice(facts)})


# ── Start ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)