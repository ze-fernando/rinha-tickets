package main

import (
	"log"
	"os"
	"rinha-tickets/go-gin/internal/database"
	"rinha-tickets/go-gin/internal/ticket"
)

func main() {
	path := os.Getenv("DATABASE_PATH")
	if path == "" {
		path = "database.sqlite"
	}
	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8000"
	}
	db, err := database.Open(path)
	if err != nil {
		log.Fatal(err)
	}
	sqlDB, err := db.DB()
	if err != nil {
		log.Fatal(err)
	}
	defer sqlDB.Close()
	if err := ticket.Router(db).Run(addr); err != nil {
		log.Print(err)
		os.Exit(1)
	}
}
