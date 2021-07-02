package com.newsblur.activity;

import android.content.Intent;
import android.net.Uri;
import android.os.Bundle;
import androidx.fragment.app.DialogFragment;
import android.view.View;

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
        binding.loadingThrob.setColors(UIUtils.getColor(this, R.color.refresh_1),
                               UIUtils.getColor(this, R.color.refresh_2),
                               UIUtils.getColor(this, R.color.refresh_3),
                               UIUtils.getColor(this, R.color.refresh_4));

        Intent intent = getIntent();
        Uri uri = intent.getData();
        
        com.newsblur.util.Log.d(this, "intent filter caught feed-like URI: " + uri);

		DialogFragment addFeedFragment = AddFeedFragment.newInstance(uri.toString(), uri.toString());
		addFeedFragment.show(getSupportFragmentManager(), "dialog");
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
