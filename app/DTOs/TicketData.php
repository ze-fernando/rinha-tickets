<?php

namespace App\DTOs;

use App\Enums\TicketStatus;

final readonly class TicketData
{
    public function __construct(
        public string $title,
        public string $description,
        public string $sector,
        public TicketStatus $status,
    ) {}

   public static function fromArray(array $data): self
    {
        $status = $data['status'] ?? TicketStatus::Open;

        return new self(
            title: $data['title'],
            description: $data['description'],
            sector: $data['sector'],
            status: $status instanceof TicketStatus ? $status : TicketStatus::from($status),
        );
    }

   public function toArray(): array
    {
        return [
            'title' => $this->title,
            'description' => $this->description,
            'sector' => $this->sector,
            'status' => $this->status,
        ];
    }
}
