package com.newsblur.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import android.view.View;
import android.widget.Toast;

import androidx.core.content.ContextCompat;
import androidx.fragment.app.DialogFragment;

import com.newsblur.R;
import com.newsblur.databinding.ActivityAddfeedexternalBinding;
import com.newsblur.fragment.AddFeedFragment;
import com.newsblur.util.UIUtils;
import com.newsblur.util.ViewUtils;

public class AddFeedExternal extends NbActivity implements AddFeedFragment.AddFeedProgressListener {

    private ActivityAddfeedexternalBinding binding;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        binding = ActivityAddfeedexternalBinding.inflate(getLayoutInflater());
        setContentView(binding.getRoot());

        UIUtils.setupToolbar(this, R.drawable.logo, "Add Feed", true);

        binding.loadingThrob.setEnabled(!ViewUtils.isPowerSaveMode(this));
        binding.loadingThrob.setColors(ContextCompat.getColor(this, R.color.refresh_1),
                ContextCompat.getColor(this, R.color.refresh_2),
                ContextCompat.getColor(this, R.color.refresh_3),
                ContextCompat.getColor(this, R.color.refresh_4));

        Intent intent = getIntent();
        Uri uri = intent.getData();

        com.newsblur.util.Log.d(this, "intent filter caught feed-like URI: " + uri);

        if (uri != null) {
            DialogFragment addFeedFragment = AddFeedFragment.newInstance(uri.toString(), uri.toString());
            addFeedFragment.show(getSupportFragmentManager(), "dialog");
        } else {
            Toast.makeText(this, "NewsBlur invalid or missing URI!", Toast.LENGTH_SHORT).show();
            startActivity(new Intent(this, InitActivity.class));
        }
    }

    @Override
    public void addFeedStarted() {
        runOnUiThread(new Runnable() {
            public void run() {
                binding.progressText.setText(R.string.adding_feed_progress);
                binding.progressText.setVisibility(View.VISIBLE);
                binding.loadingThrob.setVisibility(View.VISIBLE);
            }
        });
    }

    @Override
    public void handleUpdate(int updateType) {
        ; // we don't care about anything but completion
    }

}
