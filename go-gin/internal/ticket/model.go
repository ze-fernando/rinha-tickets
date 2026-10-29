package ticket

import "time"

type Ticket struct {
	ID          int64      `json:"id" gorm:"primaryKey;autoIncrement"`
	Title       string     `json:"title" gorm:"not null;uniqueIndex"`
	Description string     `json:"description" gorm:"not null"`
	Sector      string     `json:"sector" gorm:"not null"`
	Status      string     `json:"status" gorm:"not null;check:status IN ('open','in_progress','closed')"`
	FinishedAt  *time.Time `json:"finished_at"`
	CreatedAt   time.Time  `json:"created_at" gorm:"not null"`
	UpdatedAt   time.Time  `json:"-" gorm:"not null"`
}

// Pointers distinguish missing/null fields from valid empty strings.
type Input struct {
	Title       *string `json:"title" binding:"required"`
	Description *string `json:"description" binding:"required"`
	Sector      *string `json:"sector" binding:"required"`
	Status      *string `json:"status" binding:"required,oneof=open in_progress closed"`
}
