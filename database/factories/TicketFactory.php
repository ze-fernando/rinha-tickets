<?php

namespace Database\Factories;

use App\Enums\TicketStatus;
use App\Models\Ticket;
use Illuminate\Database\Eloquent\Factories\Factory;




class TicketFactory extends Factory
{
    




    public function definition(): array
    {
        return [
            'title' => fake()->unique()->sentence(4),
            'description' => fake()->paragraph(),
            'sector' => fake()->randomElement(['Comercial', 'Financeiro', 'RH', 'TI']),
            'status' => TicketStatus::Open,
            'finished_at' => null,
        ];
    }

    


    public function inProgress(): static
    {
        return $this->state(fn (array $attributes): array => [
            'status' => TicketStatus::InProgress,
        ]);
    }

    


    public function closed(): static
    {
        return $this->state(fn (array $attributes): array => [
            'status' => TicketStatus::Closed,
            'finished_at' => now(),
        ]);
    }
}
