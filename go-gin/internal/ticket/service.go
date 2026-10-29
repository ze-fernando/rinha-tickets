package ticket

import (
	"context"
	"time"

	"gorm.io/gorm"
)

type Service struct{ DB *gorm.DB }

func (s Service) List(ctx context.Context, open bool) ([]Ticket, error) {
	tickets := make([]Ticket, 0)
	query := s.DB.WithContext(ctx)
	if open {
		query = query.Where("status = ?", "open")
	}
	err := query.Find(&tickets).Error
	return tickets, err
}

func (s Service) Get(ctx context.Context, id int64) (Ticket, error) {
	var t Ticket
	err := s.DB.WithContext(ctx).First(&t, id).Error
	return t, err
}

func (s Service) Create(ctx context.Context, input Input) (Ticket, error) {
	t := Ticket{Title: *input.Title, Description: *input.Description, Sector: *input.Sector, Status: *input.Status}
	err := s.DB.WithContext(ctx).Create(&t).Error
	return t, err
}

func (s Service) Update(ctx context.Context, id int64, input *Input) (Ticket, error) {
	var t Ticket
	err := s.DB.WithContext(ctx).Transaction(func(db *gorm.DB) error {
		if err := db.First(&t, id).Error; err != nil {
			return err
		}
		now := time.Now().UTC()
		if input == nil {
			t.Status, t.FinishedAt = "closed", &now
		} else {
			t.Title, t.Description, t.Sector, t.Status = *input.Title, *input.Description, *input.Sector, *input.Status
			if t.Status != "closed" {
				t.FinishedAt = nil
			} else if t.FinishedAt == nil {
				t.FinishedAt = &now
			}
		}
		return db.Model(&t).Select("title", "description", "sector", "status", "finished_at", "updated_at").Updates(&t).Error
	})
	return t, err
}
