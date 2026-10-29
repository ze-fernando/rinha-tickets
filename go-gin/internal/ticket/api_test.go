package ticket_test

import (
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"rinha-tickets/go-gin/internal/database"
	"rinha-tickets/go-gin/internal/ticket"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func setup(t *testing.T) http.Handler {
	t.Helper()
	gin.SetMode(gin.TestMode)
	db, err := database.Open(filepath.Join(t.TempDir(), "tickets.sqlite"))
	if err != nil {
		t.Fatal(err)
	}
	sqlDB, _ := db.DB()
	t.Cleanup(func() { sqlDB.Close() })
	return ticket.Router(db)
}

func request(t *testing.T, router http.Handler, method, path, body string, status int) map[string]any {
	t.Helper()
	req := httptest.NewRequest(method, path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)
	if rec.Code != status {
		t.Fatalf("%s %s: want %d, got %d: %s", method, path, status, rec.Code, rec.Body.String())
	}
	var result map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatal(err)
	}
	return result
}

func TestLifecycle(t *testing.T) {
	r := setup(t)
	for _, path := range []string{"all", "open"} {
		got := request(t, r, "GET", "/api/tickets/"+path, "", 200)
		if data, ok := got["data"].([]any); !ok || len(data) != 0 {
			t.Fatalf("empty list: %v", got)
		}
	}
	body := `{"title":"Impressora","description":"Sem rede","sector":"Recepção"}`
	created := request(t, r, "POST", "/api/tickets/create", body, 201)
	id := fmt.Sprintf("%.0f", created["id"])
	base := "/api/tickets/" + id
	if created["status"] != "open" || created["finished_at"] != nil || created["created_at"] == nil {
		t.Fatal(created)
	}
	if _, ok := created["updated_at"]; ok {
		t.Fatal("updated_at exposed")
	}
	request(t, r, "GET", base, "", 200)
	duplicate := request(t, r, "POST", "/api/tickets/create", body, 409)
	if duplicate["detail"] != "Chamado já em aberto" {
		t.Fatal(duplicate)
	}
	closed := request(t, r, "PUT", base+"/update", `{"title":"Impressora","description":"","sector":"","status":"closed"}`, 200)
	if closed["finished_at"] == nil || closed["description"] != "" || closed["sector"] != "" {
		t.Fatal(closed)
	}
	preserved := request(t, r, "PUT", base+"/update", `{"title":"Impressora","description":"","sector":"","status":"closed"}`, 200)
	if closed["finished_at"] != preserved["finished_at"] {
		t.Fatal("closed update changed finish time")
	}
	time.Sleep(time.Millisecond)
	finished := request(t, r, "PUT", base+"/finish", "", 200)
	if finished["finished_at"] == preserved["finished_at"] {
		t.Fatal("finish did not reset timestamp")
	}
	reopened := request(t, r, "PUT", base+"/update", body, 200)
	if reopened["status"] != "open" || reopened["finished_at"] != nil {
		t.Fatal(reopened)
	}
	request(t, r, "PUT", base+"/update", `{"title":"Impressora","description":"x","sector":"x","status":"in_progress"}`, 200)
	opened := request(t, r, "GET", "/api/tickets/open", "", 200)
	if len(opened["data"].([]any)) != 0 {
		t.Fatal(opened)
	}
	all := request(t, r, "GET", "/api/tickets/all", "", 200)
	if len(all["data"].([]any)) != 1 {
		t.Fatal(all)
	}
	direct := request(t, r, "POST", "/api/tickets/create", `{"title":"Fechado","description":"x","sector":"x","status":"closed"}`, 201)
	if direct["finished_at"] != nil {
		t.Fatal("creation must not set finished_at")
	}
	request(t, r, "PUT", base+"/update", `{"title":"Fechado","description":"x","sector":"x"}`, 409)
	unchanged := request(t, r, "GET", base, "", 200)
	if unchanged["title"] != "Impressora" {
		t.Fatal("failed update changed persisted data")
	}
}

func TestInvalidRequests(t *testing.T) {
	r := setup(t)
	bodies := []string{"", "null", "{}", "[]", `{`, `{"title":1,"description":"x","sector":"x"}`, `{"title":null,"description":"x","sector":"x"}`, `{"title":"x","description":"x"}`, `{"title":"x","description":"x","sector":"x","status":null}`, `{"title":"x","description":"x","sector":"x","status":"invalid"}`}
	for _, body := range bodies {
		t.Run(body, func(t *testing.T) {
			request(t, r, "POST", "/api/tickets/create", body, 422)
			request(t, r, "PUT", "/api/tickets/1/update", body, 422)
		})
	}
	for _, id := range []string{"999", "0", "abc", "-1", "1.5", "1 OR 1=1"} {
		for _, route := range []struct{ method, suffix string }{{"GET", ""}, {"PUT", "/update"}, {"PUT", "/finish"}} {
			got := request(t, r, route.method, "/api/tickets/"+strings.ReplaceAll(id, " ", "%20")+route.suffix, `{"title":"x","description":"x","sector":"x"}`, 404)
			if id == "999" && got["detail"] != "Chamado não existe" {
				t.Fatal(got)
			}
		}
	}
	// Empty text fields are valid, unlike missing fields.
	request(t, r, "POST", "/api/tickets/create", `{"title":"","description":"","sector":""}`, 201)
}

func TestPersistence(t *testing.T) {
	path := filepath.Join(t.TempDir(), "tickets.sqlite")
	db, err := database.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	request(t, ticket.Router(db), "POST", "/api/tickets/create", `{"title":"Persistido","description":"x","sector":"x"}`, 201)
	conn, _ := db.DB()
	conn.Close()
	reopened, err := database.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	conn, _ = reopened.DB()
	defer conn.Close()
	got := request(t, ticket.Router(reopened), "GET", "/api/tickets/1", "", 200)
	if got["title"] != "Persistido" {
		t.Fatal(got)
	}
}
