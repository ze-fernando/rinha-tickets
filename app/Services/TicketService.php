<?php

namespace App\Services;

use App\DTOs\TicketData;
use App\Enums\TicketStatus;
use App\Exceptions\TicketAlreadyExistsException;
use App\Exceptions\TicketNotFoundException;
use App\Models\Ticket;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\UniqueConstraintViolationException;

final class TicketService
{
    


    public function findAll(): Collection
    {
        return Ticket::query()->latest()->get();
    }

    


    public function findOpen(): Collection
    {
        return Ticket::query()
            ->where('status', TicketStatus::Open)
            ->latest()
            ->get();
    }

    public function findById(int $ticketId): Ticket
    {
        return Ticket::query()->find($ticketId) ?? throw new TicketNotFoundException;
    }

    public function create(TicketData $data): Ticket
    {
        $this->ensureTitleIsAvailable($data->title);

        try {
            return Ticket::query()->create($data->toArray());
        } catch (UniqueConstraintViolationException) {
            throw new TicketAlreadyExistsException;
        }
    }

    public function update(int $ticketId, TicketData $data): Ticket
    {
        $ticket = $this->findById($ticketId);

        $this->ensureTitleIsAvailable($data->title, $ticketId);

        $ticket->fill([
            ...$data->toArray(),
            'finished_at' => $data->status === TicketStatus::Closed
                ? ($ticket->finished_at ?? now())
                : null,
        ]);

        try {
            $ticket->save();
        } catch (UniqueConstraintViolationException) {
            throw new TicketAlreadyExistsException;
        }

        return $ticket->refresh();
    }

    public function finish(int $ticketId): Ticket
    {
        $ticket = $this->findById($ticketId);

        $ticket->forceFill([
            'status' => TicketStatus::Closed,
            'finished_at' => now(),
        ])->save();

        return $ticket->refresh();
    }

    private function ensureTitleIsAvailable(string $title, ?int $ignoreTicketId = null): void
    {
        $query = Ticket::query()->where('title', $title);

        if ($ignoreTicketId !== null) {
            $query->whereKeyNot($ignoreTicketId);
        }

        if ($query->exists()) {
            throw new TicketAlreadyExistsException;
        }
    }
}
