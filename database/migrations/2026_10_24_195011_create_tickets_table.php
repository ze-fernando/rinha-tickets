<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    


    public function up(): void
    {
        Schema::create('tickets', function (Blueprint $table) {
            $table->id();
            $table->string('title')->unique();
            $table->text('description');
            $table->string('sector');
            $table->string('status')->default('open');
            $table->timestamp('finished_at')->nullable();
            $table->timestamps();
        });
    }

    


    public function down(): void
    {
        Schema::dropIfExists('tickets');
    }
};
