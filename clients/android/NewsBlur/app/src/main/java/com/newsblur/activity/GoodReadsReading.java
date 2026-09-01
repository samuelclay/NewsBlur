package com.newsblur.activity;

import android.os.Bundle;

import com.newsblur.R;
import com.newsblur.util.UIUtils;

public class GoodReadsReading extends Reading {

    @Override
    protected void onCreate(Bundle savedInstanceBundle) {
        super.onCreate(savedInstanceBundle);

        UIUtils.setupToolbar(this, R.drawable.ic_good_reads, getResources().getString(R.string.good_reads_title), false);
    }
}
