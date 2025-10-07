package com.newsblur.activity;

import android.content.res.Resources;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentPagerAdapter;

import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.fragment.ProfileActivitiesFragment;
import com.newsblur.fragment.ProfileActivityDetailsFragment;
import com.newsblur.fragment.ProfileInteractionsFragment;
import com.newsblur.util.ImageLoader;

/**
 * Created by mark on 15/06/15.
 */
public class ActivityDetailsPagerAdapter extends FragmentPagerAdapter {

    private final ProfileActivityDetailsFragment interactionsFragment;
    private final ProfileActivityDetailsFragment activitiesFragment;
    private final Profile profile;

    public ActivityDetailsPagerAdapter(FragmentManager fragmentManager, Profile profile) {
        super(fragmentManager, FragmentPagerAdapter.BEHAVIOR_RESUME_ONLY_CURRENT_FRAGMENT);

        this.profile = profile;

        interactionsFragment = new ProfileInteractionsFragment();
        activitiesFragment = new ProfileActivitiesFragment();
    }

    @Override
    public Fragment getItem(int i) {
        if (i == 0) {
            return interactionsFragment;
        } else {
            return activitiesFragment;
        }
    }

    @Override
    public int getCount() {
        return 2;
    }

    @Override
    public CharSequence getPageTitle(int position) {
        Resources resources = profile.getResources();
        if (position == 0) {
            return resources.getString(R.string.profile_recent_interactions);
        } else {
            return resources.getString(R.string.profile_recent_actvity);
        }
    }

    public void setUser(UserDetails user, ImageLoader iconLoader) {
        interactionsFragment.setUser(profile, user, iconLoader);
        activitiesFragment.setUser(profile, user, iconLoader);
    }
}
