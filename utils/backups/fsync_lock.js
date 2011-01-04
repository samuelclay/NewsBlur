function freeze_db() {
        rc = db.runCommand({fsync: 1, lock: 1});
        if (rc.ok == 1){
            return 1;
        } else {
            return 0;
        }
    }
freeze_db();