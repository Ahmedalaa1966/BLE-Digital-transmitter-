package CU_states;

    typedef enum logic [2:0] {
        IDLE,
        PVT_CAL,
        ACQUISITION,
        TRACKING,
        TRAINING,
        MODULATION,
        SLEEP
    } cu_state_t;
    endpackage