<?php

namespace Tests\Feature;

use App\Enums\TicketStatus;
use App\Models\Ticket;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class TicketApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_lists_all_tickets_from_newest_to_oldest(): void
    {
        $older = Ticket::factory()->create([
            'created_at' => now()->subDay(),
            'updated_at' => now()->subDay(),
        ]);
        $newer = Ticket::factory()->create();

        $this->getJson('/api/tickets/all')
            ->assertOk()
            ->assertJsonCount(2)
            ->assertJsonPath('0.id', $newer->id)
            ->assertJsonPath('1.id', $older->id);
    }

    public function test_lists_only_open_tickets(): void
    {
        $open = Ticket::factory()->create();
        Ticket::factory()->closed()->create();
        Ticket::factory()->inProgress()->create();

        $this->getJson('/api/tickets/open')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $open->id)
            ->assertJsonPath('0.status', 'open');
    }

    public function test_shows_a_ticket_by_id(): void
    {
        $ticket = Ticket::factory()->inProgress()->create();

        $this->getJson("/api/tickets/{$ticket->id}")
            ->assertOk()
            ->assertJsonPath('id', $ticket->id)
            ->assertJsonPath('title', $ticket->title)
            ->assertJsonPath('status', 'in_progress');
    }

    public function test_returns_not_found_error_when_ticket_does_not_exist(): void
    {
        $this->getJson('/api/tickets/999999')
            ->assertNotFound()
            ->assertJson([
                'code' => 'TICKET_NOT_FOUND',
                'message' => 'Chamado não encontrado',
            ]);
    }

    public function test_creates_a_ticket(): void
    {
        $payload = [
            'title' => 'Computador não liga',
            'description' => 'A máquina da recepção não liga desde ontem.',
            'sector' => 'TI',
        ];

        $this->postJson('/api/tickets/create', $payload)
            ->assertCreated()
            ->assertJsonPath('title', $payload['title'])
            ->assertJsonPath('status', 'open')
            ->assertJsonPath('finished_at', null);

        $this->assertDatabaseHas('tickets', [
            'title' => $payload['title'],
            'description' => $payload['description'],
            'sector' => $payload['sector'],
            'status' => 'open',
        ]);
    }

    public function test_normalizes_status_case_when_creating_a_ticket(): void
    {
        $this->postJson('/api/tickets/create', [
            'title' => 'Acesso ao sistema',
            'description' => 'Solicitação de acesso ao ERP.',
            'sector' => 'Financeiro',
            'status' => 'IN_PROGRESS',
        ])
            ->assertCreated()
            ->assertJsonPath('status', 'in_progress');
    }

    public function test_returns_conflict_when_title_already_exists(): void
    {
        Ticket::factory()->create(['title' => 'Título repetido']);

        $this->postJson('/api/tickets/create', [
            'title' => 'Título repetido',
            'description' => 'Outra descrição.',
            'sector' => 'TI',
        ])
            ->assertConflict()
            ->assertJson([
                'code' => 'TICKET_ALREADY_EXISTS',
                'message' => 'Chamado já em aberto',
            ]);
    }

    public function test_validates_the_create_payload(): void
    {
        $this->postJson('/api/tickets/create', [
            'title' => 'Chamado sem descrição',
            'sector' => 'TI',
        ])
            ->assertUnprocessable()
            ->assertJsonPath('code', 'VALIDATION_ERROR')
            ->assertJsonValidationErrors(['description']);
    }

    public function test_updates_a_ticket_and_finishes_it_when_status_is_closed(): void
    {
        $ticket = Ticket::factory()->create();

        $this->putJson("/api/tickets/{$ticket->id}/update", [
            'title' => 'Título atualizado',
            'description' => 'Descrição atualizada.',
            'sector' => 'RH',
            'status' => 'closed',
        ])
            ->assertOk()
            ->assertJsonPath('title', 'Título atualizado')
            ->assertJsonPath('status', 'closed');

        $this->assertNotNull($ticket->fresh()->finished_at);
    }

    public function test_reopens_a_closed_ticket_when_status_changes(): void
    {
        $ticket = Ticket::factory()->closed()->create();

        $this->putJson("/api/tickets/{$ticket->id}/update", [
            'title' => $ticket->title,
            'description' => $ticket->description,
            'sector' => $ticket->sector,
            'status' => 'open',
        ])
            ->assertOk()
            ->assertJsonPath('status', 'open')
            ->assertJsonPath('finished_at', null);

        $this->assertNull($ticket->fresh()->finished_at);
    }

    public function test_returns_not_found_when_updating_a_missing_ticket(): void
    {
        $this->putJson('/api/tickets/999999/update', [
            'title' => 'Qualquer',
            'description' => 'Qualquer',
            'sector' => 'TI',
        ])
            ->assertNotFound()
            ->assertJsonPath('code', 'TICKET_NOT_FOUND');
    }

    public function test_finishes_a_ticket(): void
    {
        $ticket = Ticket::factory()->inProgress()->create();

        $this->putJson("/api/tickets/{$ticket->id}/finish")
            ->assertOk()
            ->assertJsonPath('status', 'closed');

        $this->assertNotNull($ticket->fresh()->finished_at);
        $this->assertSame(TicketStatus::Closed, $ticket->fresh()->status);
    }

    public function test_returns_not_found_when_finishing_a_missing_ticket(): void
    {
        $this->putJson('/api/tickets/999999/finish')
            ->assertNotFound()
            ->assertJsonPath('code', 'TICKET_NOT_FOUND');
    }

    public function test_accepts_form_encoded_payload_when_updating(): void
    {
        $ticket = Ticket::factory()->create();

        $this->put("/api/tickets/{$ticket->id}/update", [
            'title' => 'Atualizado por formulário',
            'description' => 'Descrição enviada como formulário.',
            'sector' => 'Comercial',
            'status' => 'open',
        ])
            ->assertOk()
            ->assertJsonPath('title', 'Atualizado por formulário');
    }
}
