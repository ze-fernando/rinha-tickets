package database

import (
	"rinha-tickets/go-gin/internal/ticket"

	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

func Open(path string) (*gorm.DB, error) {
	db, err := gorm.Open(sqlite.Open(path), &gorm.Config{TranslateError: true})
	if err != nil {
		return nil, err
	}
	sqlDB, err := db.DB()
	if err != nil {
		return nil, err
	}
	// Serialize access to SQLite, including in-memory databases.
	sqlDB.SetMaxOpenConns(1)
	if err = db.AutoMigrate(&ticket.Ticket{}); err != nil {
		sqlDB.Close()
		return nil, err
	}
	return db, nil
}
