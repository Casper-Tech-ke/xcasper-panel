<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('xcasper_transactions', function (Blueprint $table) {
            $table->id();
            $table->unsignedInteger('user_id');
            $table->unsignedInteger('amount_kes');
            $table->string('type'); // paystack, manual
            $table->string('plan'); // basic, pro, admin
            $table->string('reference')->nullable();
            $table->string('description')->nullable();
            $table->string('status')->default('pending'); // pending, success, failed
            $table->timestamps();

            $table->foreign('user_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('xcasper_transactions');
    }
};