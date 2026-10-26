from pathlib import Path

STATIC = Path(__file__).parent.parent / "app" / "static"


def test_root_redirects_to_ui(client):
    response = client.get("/", follow_redirects=False)
    assert response.status_code in (302, 307)
    assert response.headers["location"] == "/ui/"


def test_ui_page_and_assets_are_served(client):
    page = client.get("/ui/")
    assert page.status_code == 200
    assert "Cloud Operations Dashboard" in page.text
    assert client.get("/ui/app.js").status_code == 200
    assert client.get("/ui/style.css").status_code == 200


def test_ui_has_restrictive_security_headers(client):
    headers = client.get("/ui/").headers
    csp = headers["content-security-policy"]
    assert "default-src 'self'" in csp
    assert "frame-ancestors 'none'" in csp
    assert headers["x-frame-options"] == "DENY"
    assert headers["x-content-type-options"] == "nosniff"


def test_csp_not_applied_to_api_docs_which_need_cdn_scripts(client):
    response = client.get("/docs")
    assert response.status_code == 200
    assert "content-security-policy" not in response.headers


def test_nosniff_on_api_responses(client):
    assert client.get("/health").headers["x-content-type-options"] == "nosniff"


def test_ui_code_never_inserts_data_as_html():
    # Guard against cross-site scripting: data must only be inserted as text.
    source = (STATIC / "app.js").read_text()
    for dangerous in ("innerHTML", "outerHTML", "insertAdjacentHTML", "document.write", "eval("):
        assert dangerous not in source


def test_ui_does_not_store_the_api_key_in_the_browser():
    source = (STATIC / "app.js").read_text()
    for storage in ("localStorage", "sessionStorage", "document.cookie"):
        assert storage not in source


def test_ui_has_no_inline_script_or_external_resources():
    html = (STATIC / "index.html").read_text()
    assert "http://" not in html and "https://" not in html
    assert "<script>" not in html  # only <script src="app.js">
