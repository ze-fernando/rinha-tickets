package ticket

import (
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func Router(db *gorm.DB) *gin.Engine {
	r := gin.New()
	r.Use(gin.Logger(), gin.Recovery())
	r.SetTrustedProxies(nil)
	r.NoRoute(func(c *gin.Context) { c.JSON(404, gin.H{"detail": "Not Found"}) })
	s := Service{DB: db}
	group := r.Group("/api/tickets")
	for _, path := range []string{"/all", "/open"} {
		open := path == "/open"
		group.GET(path, func(c *gin.Context) {
			tickets, err := s.List(c.Request.Context(), open)
			if respondError(c, err) {
				return
			}
			c.JSON(http.StatusOK, gin.H{"data": tickets})
		})
	}
	group.POST("/create", func(c *gin.Context) {
		input, ok := bind(c)
		if !ok {
			return
		}
		t, err := s.Create(c.Request.Context(), input)
		if !respondError(c, err) {
			c.JSON(http.StatusCreated, t)
		}
	})
	group.GET("/:id", func(c *gin.Context) {
		id, ok := parseID(c)
		if !ok {
			return
		}
		t, err := s.Get(c.Request.Context(), id)
		if !respondError(c, err) {
			c.JSON(http.StatusOK, t)
		}
	})
	group.PUT("/:id/update", func(c *gin.Context) {
		id, ok := parseID(c)
		if !ok {
			return
		}
		input, ok := bind(c)
		if !ok {
			return
		}
		t, err := s.Update(c.Request.Context(), id, &input)
		if !respondError(c, err) {
			c.JSON(http.StatusOK, t)
		}
	})
	group.PUT("/:id/finish", func(c *gin.Context) {
		id, ok := parseID(c)
		if !ok {
			return
		}
		t, err := s.Update(c.Request.Context(), id, nil)
		if !respondError(c, err) {
			c.JSON(http.StatusOK, t)
		}
	})
	return r
}

func bind(c *gin.Context) (Input, bool) {
	status := "open"
	input := Input{Status: &status}
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusUnprocessableEntity, gin.H{"detail": err.Error()})
		return input, false
	}
	return input, true
}

func parseID(c *gin.Context) (int64, bool) {
	raw := c.Param("id")
	// Match the unsigned decimal path converter of the reference API.
	valid := raw != "" && strings.IndexFunc(raw, func(r rune) bool { return r < '0' || r > '9' }) == -1
	id, err := strconv.ParseInt(raw, 10, 64)
	if !valid || err != nil {
		c.JSON(http.StatusNotFound, gin.H{"detail": "Not Found"})
		return 0, false
	}
	return id, true
}

func respondError(c *gin.Context, err error) bool {
	if err == nil {
		return false
	}
	switch {
	case errors.Is(err, gorm.ErrRecordNotFound):
		c.JSON(http.StatusNotFound, gin.H{"detail": "Chamado não existe"})
	case errors.Is(err, gorm.ErrDuplicatedKey):
		c.JSON(http.StatusConflict, gin.H{"detail": "Chamado já em aberto"})
	default:
		log.Printf("ticket request failed: %v", err)
		c.JSON(http.StatusInternalServerError, gin.H{"detail": "Erro interno do servidor"})
	}
	return true
}
