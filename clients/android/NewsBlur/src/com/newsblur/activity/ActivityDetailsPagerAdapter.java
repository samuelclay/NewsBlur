package com.newsblur.activity;

import android.app.Fragment;
import android.app.FragmentManager;
import android.content.res.Resources;
import android.support.v13.app.FragmentPagerAdapter;

import com.newsblur.R;
import com.newsblur.domain.UserDetails;
import com.newsblur.fragment.ProfileActivitiesFragment;
import com.newsblur.fragment.ProfileActivityDetailsFragment;
import com.newsblur.fragment.ProfileInteractionsFragment;

/**
 * Created by mark on 15/06/15.
 */
public class ActivityDetailsPagerAdapter extends FragmentPagerAdapter {

    private final ProfileActivityDetailsFragment interactionsFragment;
    private final ProfileActivityDetailsFragment activitiesFragment;
    private final Profile profile;

    public ActivityDetailsPagerAdapter(FragmentManager fragmentManager, Profile profile) {
        super(fragmentManager);

        this.profile = profile;

        interactionsFragment = new ProfileInteractionsFragment();
        interactionsFragment.setRetainInstance(true);
        activitiesFragment = new ProfileActivitiesFragment();
        activitiesFragment.setRetainInstance(true);
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

    public void setUser(UserDetails user) {
        interactionsFragment.setUser(profile, user);
        activitiesFragment.setUser(profile, user);
    }
}
