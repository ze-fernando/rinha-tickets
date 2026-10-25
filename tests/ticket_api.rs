use std::time::Duration;

use axum::Router;
use axum::body::Body;
use axum::http::{Request, StatusCode};
use http_body_util::BodyExt;
use serde_json::{Value, json};
use tempfile::TempDir;
use tower::ServiceExt;

use tickets::db::Db;
use tickets::state::AppState;
use tickets::ticket::routes::router;

struct TestApp {
    router: Router,
    _directory: TempDir,
}

impl TestApp {
    fn new() -> Self {
        let directory = tempfile::tempdir().expect("criar diretório temporário");
        let database_url = directory.path().join("tickets.sqlite");

        let db = Db::connect(database_url.to_str().expect("caminho do banco em UTF-8"))
            .expect("conectar ao banco");
        db.run_migrations().expect("executar migrations");

        let router = router(AppState { db });

        Self {
            router,
            _directory: directory,
        }
    }

    async fn send(&self, request: Request<Body>) -> (StatusCode, Value) {
        let response = self
            .router
            .clone()
            .oneshot(request)
            .await
            .expect("executar requisição");

        let status = response.status();
        let body = response
            .into_body()
            .collect()
            .await
            .expect("ler corpo da resposta")
            .to_bytes();

        let json = if body.is_empty() {
            Value::Null
        } else {
            serde_json::from_slice(&body).expect("resposta em JSON")
        };

        (status, json)
    }
}

fn json_request(method: &str, uri: &str, body: Value) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .header("content-type", "application/json")
        .body(Body::from(body.to_string()))
        .expect("montar requisição JSON")
}

fn empty_request(method: &str, uri: &str) -> Request<Body> {
    Request::builder()
        .method(method)
        .uri(uri)
        .body(Body::empty())
        .expect("montar requisição")
}

async fn create_ticket(app: &TestApp, title: &str, status: Option<&str>) -> (StatusCode, Value) {
    let mut payload = json!({
        "title": title,
        "description": format!("Descrição de {title}"),
        "sector": "TI",
    });

    if let Some(status) = status {
        payload["status"] = json!(status);
    }

    app.send(json_request("POST", "/api/tickets/create", payload))
        .await
}

fn ticket_id(body: &Value) -> i32 {
    body["id"].as_i64().expect("id do chamado") as i32
}

#[tokio::test]
async fn lists_all_tickets_from_newest_to_oldest() {
    let app = TestApp::new();

    let (_, first) = create_ticket(&app, "Primeiro chamado", None).await;
    tokio::time::sleep(Duration::from_millis(2)).await;
    let (_, second) = create_ticket(&app, "Segundo chamado", None).await;

    let (status, body) = app.send(empty_request("GET", "/api/tickets/all")).await;

    assert_eq!(status, StatusCode::OK);
    let tickets = body.as_array().expect("lista de chamados");
    assert_eq!(tickets.len(), 2);
    assert_eq!(tickets[0]["id"], second["id"]);
    assert_eq!(tickets[1]["id"], first["id"]);
}

#[tokio::test]
async fn lists_only_open_tickets() {
    let app = TestApp::new();

    let (_, open) = create_ticket(&app, "Chamado aberto", None).await;
    create_ticket(&app, "Chamado fechado", Some("closed")).await;
    create_ticket(&app, "Chamado em andamento", Some("in_progress")).await;

    let (status, body) = app.send(empty_request("GET", "/api/tickets/open")).await;

    assert_eq!(status, StatusCode::OK);
    let tickets = body.as_array().expect("lista de chamados");
    assert_eq!(tickets.len(), 1);
    assert_eq!(tickets[0]["id"], open["id"]);
    assert_eq!(tickets[0]["status"], "open");
}

#[tokio::test]
async fn shows_a_ticket_by_id() {
    let app = TestApp::new();

    let (_, created) = create_ticket(&app, "Chamado para consulta", Some("IN_PROGRESS")).await;
    let id = ticket_id(&created);

    let (status, body) = app
        .send(empty_request("GET", &format!("/api/tickets/{id}")))
        .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["id"], id);
    assert_eq!(body["title"], "Chamado para consulta");
    assert_eq!(body["status"], "in_progress");
}

#[tokio::test]
async fn returns_not_found_for_missing_ticket() {
    let app = TestApp::new();

    let (status, body) = app.send(empty_request("GET", "/api/tickets/999999")).await;

    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["code"], "TICKET_NOT_FOUND");
    assert_eq!(body["message"], "Chamado não encontrado");
}

#[tokio::test]
async fn creates_a_ticket_with_default_status() {
    let app = TestApp::new();

    let (status, body) = create_ticket(&app, "Novo chamado", None).await;

    assert_eq!(status, StatusCode::CREATED);
    assert!(body["id"].as_i64().is_some());
    assert_eq!(body["title"], "Novo chamado");
    assert_eq!(body["status"], "open");
    assert!(body["finished_at"].is_null());
    assert!(body["created_at"].is_string());
    assert!(body["updated_at"].is_string());
}

#[tokio::test]
async fn accepts_status_in_any_case() {
    let app = TestApp::new();

    let (status, body) = create_ticket(&app, "Chamado com status maiúsculo", Some("CLOSED")).await;

    assert_eq!(status, StatusCode::CREATED);
    assert_eq!(body["status"], "closed");
}

#[tokio::test]
async fn returns_conflict_when_title_already_exists() {
    let app = TestApp::new();

    create_ticket(&app, "Título repetido", None).await;

    let (status, body) = create_ticket(&app, "Título repetido", None).await;

    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(body["code"], "TICKET_ALREADY_EXISTS");
    assert_eq!(body["message"], "Chamado já em aberto");
}

#[tokio::test]
async fn validates_the_create_payload() {
    let app = TestApp::new();

    let payload = json!({
        "title": "Chamado sem descrição",
        "sector": "TI",
    });

    let (status, body) = app
        .send(json_request("POST", "/api/tickets/create", payload))
        .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["code"], "VALIDATION_ERROR");
    assert_eq!(
        body["errors"]["description"][0],
        "A descrição é obrigatória."
    );
}

#[tokio::test]
async fn rejects_an_invalid_status() {
    let app = TestApp::new();

    let payload = json!({
        "title": "Chamado com status inválido",
        "description": "Descrição.",
        "sector": "TI",
        "status": "invalid",
    });

    let (status, body) = app
        .send(json_request("POST", "/api/tickets/create", payload))
        .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(
        body["errors"]["status"][0],
        "O status deve ser open, in_progress ou closed."
    );
}

#[tokio::test]
async fn rejects_empty_required_fields() {
    let app = TestApp::new();

    let payload = json!({
        "title": "   ",
        "description": "",
        "sector": "TI",
    });

    let (status, body) = app
        .send(json_request("POST", "/api/tickets/create", payload))
        .await;

    assert_eq!(status, StatusCode::UNPROCESSABLE_ENTITY);
    assert_eq!(body["errors"]["title"][0], "O título é obrigatório.");
    assert_eq!(
        body["errors"]["description"][0],
        "A descrição é obrigatória."
    );
}

#[tokio::test]
async fn updates_a_ticket_and_closes_it() {
    let app = TestApp::new();

    let (_, created) = create_ticket(&app, "Chamado para atualizar", None).await;
    let id = ticket_id(&created);

    let payload = json!({
        "title": "Chamado atualizado",
        "description": "Descrição atualizada.",
        "sector": "RH",
        "status": "closed",
    });

    let (status, body) = app
        .send(json_request(
            "PUT",
            &format!("/api/tickets/{id}/update"),
            payload,
        ))
        .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["title"], "Chamado atualizado");
    assert_eq!(body["sector"], "RH");
    assert_eq!(body["status"], "closed");
    assert!(body["finished_at"].is_string());
}

#[tokio::test]
async fn reopens_a_closed_ticket() {
    let app = TestApp::new();

    let (_, created) = create_ticket(&app, "Chamado fechado", Some("closed")).await;
    let id = ticket_id(&created);

    let payload = json!({
        "title": "Chamado reaberto",
        "description": "Descrição do chamado reaberto.",
        "sector": "TI",
        "status": "open",
    });

    let (status, body) = app
        .send(json_request(
            "PUT",
            &format!("/api/tickets/{id}/update"),
            payload,
        ))
        .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["status"], "open");
    assert!(body["finished_at"].is_null());
}

#[tokio::test]
async fn returns_conflict_when_updating_to_an_existing_title() {
    let app = TestApp::new();

    create_ticket(&app, "Título existente", None).await;
    let (_, created) = create_ticket(&app, "Outro título", None).await;
    let id = ticket_id(&created);

    let payload = json!({
        "title": "Título existente",
        "description": "Descrição.",
        "sector": "TI",
    });

    let (status, body) = app
        .send(json_request(
            "PUT",
            &format!("/api/tickets/{id}/update"),
            payload,
        ))
        .await;

    assert_eq!(status, StatusCode::CONFLICT);
    assert_eq!(body["code"], "TICKET_ALREADY_EXISTS");
}

#[tokio::test]
async fn returns_not_found_when_updating_a_missing_ticket() {
    let app = TestApp::new();

    let payload = json!({
        "title": "Qualquer",
        "description": "Qualquer",
        "sector": "TI",
    });

    let (status, body) = app
        .send(json_request("PUT", "/api/tickets/999999/update", payload))
        .await;

    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["code"], "TICKET_NOT_FOUND");
}

#[tokio::test]
async fn finishes_a_ticket() {
    let app = TestApp::new();

    let (_, created) = create_ticket(&app, "Chamado em andamento", Some("in_progress")).await;
    let id = ticket_id(&created);

    let (status, body) = app
        .send(empty_request("PUT", &format!("/api/tickets/{id}/finish")))
        .await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body["status"], "closed");
    assert!(body["finished_at"].is_string());
}

#[tokio::test]
async fn returns_not_found_when_finishing_a_missing_ticket() {
    let app = TestApp::new();

    let (status, body) = app
        .send(empty_request("PUT", "/api/tickets/999999/finish"))
        .await;

    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["code"], "TICKET_NOT_FOUND");
}

#[tokio::test]
async fn returns_json_for_unknown_routes() {
    let app = TestApp::new();

    let (status, body) = app
        .send(empty_request("GET", "/api/rota-inexistente"))
        .await;

    assert_eq!(status, StatusCode::NOT_FOUND);
    assert_eq!(body["code"], "RESOURCE_NOT_FOUND");
    assert_eq!(body["message"], "Recurso não encontrado.");
}

#[tokio::test]
async fn returns_an_empty_list_when_there_are_no_tickets() {
    let app = TestApp::new();

    let (status, body) = app.send(empty_request("GET", "/api/tickets/all")).await;

    assert_eq!(status, StatusCode::OK);
    assert_eq!(body, json!([]));
}
