<?php

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Database\Migrations\Migration;

class AddBackupLimitToServers extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        $driver = DB::connection()->getDriverName();

        if ($driver === 'sqlite') {
            $columns = DB::select("PRAGMA table_info('servers')");
            $exists = collect($columns)->contains(fn($col) => $col->name === 'backup_limit');
        } else {
            $db = config('database.default');
            $results = DB::select('SELECT * FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = ? AND TABLE_NAME = \'servers\' AND COLUMN_NAME = \'backup_limit\'', [
                config("database.connections.{$db}.database"),
            ]);
            $exists = count($results) === 1;
        }

        if ($exists) {
            Schema::table('servers', function (Blueprint $table) {
                $table->unsignedInteger('backup_limit')->default(0)->change();
            });
        } else {
            Schema::table('servers', function (Blueprint $table) {
                $table->unsignedInteger('backup_limit')->default(0)->after('database_limit');
            });
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('servers', function (Blueprint $table) {
            $table->dropColumn('backup_limit');
        });
    }
}