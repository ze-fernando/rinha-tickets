<?php

namespace App\Models;

use App\Enums\TicketStatus;
use Database\Factories\TicketFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

#[Fillable(['title', 'description', 'sector', 'status', 'finished_at'])]
class Ticket extends Model
{
    
    use HasFactory;

    




    protected function casts(): array
    {
        return [
            'status' => TicketStatus::class,
            'finished_at' => 'datetime',
        ];
    }
}
