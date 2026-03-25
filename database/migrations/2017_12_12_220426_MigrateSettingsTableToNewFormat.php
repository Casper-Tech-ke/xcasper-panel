<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class MigrateSettingsTableToNewFormat extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        DB::table('settings')->truncate();

        if (DB::connection()->getDriverName() === 'sqlite') {
            Schema::create('settings_new', function (Blueprint $table) {
                $table->increments('id');
                $table->string('key')->unique();
                $table->text('value');
            });
            Schema::drop('settings');
            Schema::rename('settings_new', 'settings');
        } else {
            Schema::table('settings', function (Blueprint $table) {
                $table->increments('id')->first();
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('settings', function (Blueprint $table) {
            $table->dropColumn('id');
        });
    }
}