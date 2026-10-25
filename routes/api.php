<?php

use App\Http\Controllers\TicketController;
use Illuminate\Support\Facades\Route;

Route::prefix('tickets')->controller(TicketController::class)->group(function (): void {
    Route::get('all', 'findAll')->name('tickets.all');
    Route::get('open', 'findOpen')->name('tickets.open');
    Route::get('{ticketId}', 'findById')->whereNumber('ticketId')->name('tickets.show');
    Route::post('create', 'create')->name('tickets.create');
    Route::put('{ticketId}/update', 'update')->whereNumber('ticketId')->name('tickets.update');
    Route::put('{ticketId}/finish', 'finish')->whereNumber('ticketId')->name('tickets.finish');
});
