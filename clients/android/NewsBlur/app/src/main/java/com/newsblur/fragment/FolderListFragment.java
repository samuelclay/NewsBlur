package com.newsblur.fragment;

import java.lang.ref.WeakReference;
import java.util.HashSet;
import java.util.Set;

import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.Parcelable;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.content.ContextCompat;
import androidx.fragment.app.DialogFragment;
import androidx.lifecycle.ViewModelProvider;

import android.os.Handler;
import android.text.Editable;
import android.text.InputType;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.view.ContextMenu;
import android.view.ContextMenu.ContextMenuInfo;
import android.view.KeyEvent;
import android.view.LayoutInflater;
import android.view.MenuInflater;
import android.view.MenuItem;
import android.view.View;
import android.view.View.OnCreateContextMenuListener;
import android.view.ViewGroup;
import android.view.inputmethod.EditorInfo;
import android.widget.ExpandableListView;
import android.widget.ExpandableListView.OnChildClickListener;
import android.widget.ExpandableListView.OnGroupClickListener;
import android.widget.ExpandableListView.OnGroupCollapseListener;
import android.widget.ExpandableListView.OnGroupExpandListener;
import android.view.inputmethod.InputMethodManager;

import com.newsblur.R;
import com.newsblur.activity.AllSharedStoriesItemsList;
import com.newsblur.activity.AllStoriesItemsList;
import com.newsblur.activity.DailyBriefingActivity;
import com.newsblur.activity.FeedItemsList;
import com.newsblur.activity.FolderItemsList;
import com.newsblur.activity.GlobalSharedStoriesItemsList;
import com.newsblur.activity.InfrequentItemsList;
import com.newsblur.activity.ItemsList;
import com.newsblur.activity.Main;
import com.newsblur.activity.MuteConfig;
import com.newsblur.activity.NbActivity;
import com.newsblur.activity.ReadStoriesItemsList;
import com.newsblur.activity.SavedStoriesItemsList;
import com.newsblur.activity.SocialFeedItemsList;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.database.FolderListAdapter;
import com.newsblur.databinding.FragmentFolderfeedlistBinding;
import com.newsblur.databinding.ViewFeedListSearchHeaderBinding;
import com.newsblur.di.IconLoader;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.domain.SavedSearch;
import com.newsblur.domain.SocialFeed;
import com.newsblur.preference.PrefsRepo;
import com.newsblur.util.Session;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedExt;
import com.newsblur.util.SessionDataSource;
import com.newsblur.util.SpacingStyle;
import com.newsblur.util.FeedSet;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.ImageLoader;
import com.newsblur.util.StateFilter;
import com.newsblur.util.TryFeedStore;
import com.newsblur.util.ListTextSize;
import com.newsblur.viewModel.AllFoldersViewModel;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class FolderListFragment extends NbFragment implements OnCreateContextMenuListener,
                                                              OnChildClickListener,
                                                              OnGroupClickListener,
                                                              OnGroupCollapseListener,
                                                              OnGroupExpandListener {
    private static final String BUNDLE_LIST_STATE = "folderListState";

    @Inject
    FeedUtils feedUtils;

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    @IconLoader
    ImageLoader iconLoader;

    @Inject
    PrefsRepo prefsRepo;

    @Inject
    TryFeedStore tryFeedStore;

    private AllFoldersViewModel allFoldersViewModel;
	private FolderListAdapter adapter;
	public StateFilter currentState = StateFilter.SOME;
	private FragmentFolderfeedlistBinding binding;
    private ViewFeedListSearchHeaderBinding searchHeaderBinding;
    private boolean isSyncingSearchField = false;
    public boolean firstCursorSeenYet = false;
    private boolean hasShownFeedsLimitDialog = false;
    @Nullable
    private Parcelable pendingListState;
    private boolean hasRestoredListState = false;

    // the two-step context menu for feeds requires us to temp store the feed long-pressed so
    // it can be accessed during the sub-menu tap
    private Feed lastMenuFeed;

	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		allFoldersViewModel = new ViewModelProvider(this).get(AllFoldersViewModel.class);
        currentState = prefsRepo.getStateFilter();
		adapter = new FolderListAdapter(getActivity(), currentState, iconLoader, dbHelper, prefsRepo);
        adapter.setToggleAllFoldersClickListener(this::toggleAllFolders);
        feedUtils.currentFolderName = null;
        // NB: it is by design that loaders are not started until we get a
        // ping from the sync service indicating that it has initialised
    }

    @Override
    public void onViewCreated(@NonNull View view, @Nullable Bundle savedInstanceState) {
        super.onViewCreated(view, savedInstanceState);
        setupObservers();
    }

    @Override
    public void onViewStateRestored(@Nullable Bundle savedInstanceState) {
        super.onViewStateRestored(savedInstanceState);
        if (savedInstanceState == null) {
            return;
        }
        pendingListState = savedInstanceState.getParcelable(BUNDLE_LIST_STATE);
        hasRestoredListState = false;
    }

    @Override
    public void onResume() {
        super.onResume();
        if (adapter != null) {
            float textSize = prefsRepo.getListTextSize();
            SpacingStyle spacingStyle = prefsRepo.getSpacingStyle();
            adapter.setTextSize(textSize);
            adapter.setSpacingStyle(spacingStyle);
            adapter.setTryFeed(tryFeedStore.get());
            adapter.notifyDataSetChanged();
        }
    }

    private void setupObservers() {
        allFoldersViewModel.getSocialFeeds().observe(getViewLifecycleOwner(), socialFeeds -> {
            adapter.setSocialFeeds(socialFeeds);
            pushUnreadCounts();
            restoreListStateIfReady();
        });
        allFoldersViewModel.getFolders().observe(getViewLifecycleOwner(), foldersResult -> {
            adapter.setFolders(foldersResult);
            pushUnreadCounts();
            restoreListStateIfReady();
        });
        allFoldersViewModel.getFeeds().observe(getViewLifecycleOwner(), feedQueryResult -> {
            adapter.setFeeds(feedQueryResult);
            adapter.setTryFeed(tryFeedStore.get());
            checkOpenFolderPreferences();
            firstCursorSeenYet = true;
            pushUnreadCounts();
            checkAccountFeedsLimit();
            restoreListStateIfReady();
        });
        allFoldersViewModel.getSavedStoryCounts().observe(getViewLifecycleOwner(), savedStoryCountsResult ->
                adapter.setStarredCount(savedStoryCountsResult));
        allFoldersViewModel.getSavedSearch().observe(getViewLifecycleOwner(), savedSearches -> {
            adapter.setSavedSearches(savedSearches);
            checkOpenFolderPreferences();
            restoreListStateIfReady();
        });
    }

	public void hasUpdated() {
        if (isAdded()) {
            allFoldersViewModel.getData();
            com.newsblur.util.Log.d(this, "loading feeds in mode: " + currentState);
        }
	}

    public void loadData() {
        if (allFoldersViewModel.getFolders().getValue() == null) {
            // if the data haven't yet been fetched, do so
            allFoldersViewModel.getData();
        }
    }

    public void reset() {
        if (adapter != null) adapter.reset();
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        View v = inflater.inflate(R.layout.fragment_folderfeedlist, container);
        binding = FragmentFolderfeedlistBinding.bind(v);
        searchHeaderBinding = ViewFeedListSearchHeaderBinding.inflate(inflater, binding.folderfeedList, false);
        configureSearchInput();

        binding.folderfeedList.setGroupIndicator(ContextCompat.getDrawable(requireContext(), R.drawable.transparent));
        binding.folderfeedList.setItemsCanFocus(true);
        binding.folderfeedList.setDescendantFocusability(ViewGroup.FOCUS_AFTER_DESCENDANTS);
        binding.folderfeedList.setOnCreateContextMenuListener(this);
        binding.folderfeedList.setOnChildClickListener(this);
        binding.folderfeedList.setOnGroupClickListener(this);
        binding.folderfeedList.setOnGroupCollapseListener(this);
        binding.folderfeedList.setOnGroupExpandListener(this);
        binding.folderfeedList.addHeaderView(searchHeaderBinding.getRoot(), null, false);

        adapter.listBackref = new WeakReference<>(binding.folderfeedList); // see note in adapter about backref
        binding.folderfeedList.setAdapter(adapter);

        // Main activity needs to listen for scrolls to prevent refresh from firing unnecessarily
        binding.folderfeedList.setOnScrollListener((android.widget.AbsListView.OnScrollListener) getActivity());
        searchHeaderBinding.inputSearchQuery.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {
            }

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {
                if (isSyncingSearchField) {
                    return;
                }
                updateSearchClearButton(s);
                applySearchQuery((s == null) ? null : s.toString(), false);
            }

            @Override
            public void afterTextChanged(Editable s) {
            }
        });
        searchHeaderBinding.inputSearchQuery.setOnEditorActionListener((textView, actionId, event) -> {
            boolean isSearchAction =
                    actionId == EditorInfo.IME_ACTION_SEARCH ||
                    actionId == EditorInfo.IME_ACTION_DONE ||
                    ((event != null) &&
                     (event.getKeyCode() == KeyEvent.KEYCODE_ENTER) &&
                     (event.getAction() == KeyEvent.ACTION_DOWN));
            if (!isSearchAction) {
                return false;
            }
            applySearchQuery((textView.getText() == null) ? null : textView.getText().toString(), false);
            return true;
        });
        searchHeaderBinding.clearSearchQuery.setOnClickListener(v1 -> {
            searchHeaderBinding.inputSearchQuery.setText("");
            searchHeaderBinding.inputSearchQuery.requestFocus();
        });
        syncSearchField(adapter.activeSearchQuery);

        return v;
    }

    private void configureSearchInput() {
        searchHeaderBinding.getRoot().setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO_EXCLUDE_DESCENDANTS);
        searchHeaderBinding.inputSearchQuery.setAutofillHints((String[]) null);
        searchHeaderBinding.inputSearchQuery.setImportantForAutofill(View.IMPORTANT_FOR_AUTOFILL_NO);
        searchHeaderBinding.inputSearchQuery.setSaveEnabled(false);
        searchHeaderBinding.inputSearchQuery.setRawInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_NO_SUGGESTIONS);
        searchHeaderBinding.inputSearchQuery.setImeOptions(EditorInfo.IME_ACTION_SEARCH | EditorInfo.IME_FLAG_NO_PERSONALIZED_LEARNING);
    }

    /**
     * Check the open/closed status of folders against what we have stored in the prefs
     * database.  The list widget likes to default all folders to closed, so open them up
     * unless expressly collapsed at some point.
     */
	public void checkOpenFolderPreferences() {
        // make sure we didn't beat construction
        if (this.binding.folderfeedList == null) return;

		for (int i = 0; i < adapter.getGroupCount(); i++) {
			String flatGroupName = adapter.getGroupUniqueName(i);
			if (prefsRepo.getBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, true)) {
				if (binding.folderfeedList.isGroupExpanded(i) == false) {
                    binding.folderfeedList.expandGroup(i);
                    adapter.setFolderClosed(flatGroupName, false);
                }
			} else {
				if (binding.folderfeedList.isGroupExpanded(i) == true) {
                    binding.folderfeedList.collapseGroup(i);
                    adapter.setFolderClosed(flatGroupName, true);
                }
			}
		}
	}

    private void toggleAllFolders() {
        boolean expandAll = adapter.areAllVisibleFoldersCollapsed();
        for (String flatFolderName : adapter.getAllFolderFlatNames()) {
            prefsRepo.putBoolean(AppConstants.FOLDER_PRE + "_" + flatFolderName, expandAll);
        }
        adapter.setAllFoldersClosed(!expandAll);
        checkOpenFolderPreferences();
    }

	@Override
	public void onCreateContextMenu(ContextMenu menu, View v, ContextMenuInfo menuInfo) {
		MenuInflater inflater = getActivity().getMenuInflater();
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) menuInfo;
		int type = ExpandableListView.getPackedPositionType(info.packedPosition);
        int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
        int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);

		switch(type) {
		case ExpandableListView.PACKED_POSITION_TYPE_GROUP:
            if (adapter.isRowSavedStories(groupPosition)) break;
            if (currentState == StateFilter.SAVED) break;
            if (adapter.isRowReadStories(groupPosition)) break;
            if (adapter.isRowDailyBriefing(groupPosition)) break;
            if (adapter.isRowGlobalSharedStories(groupPosition)) break;
            if (adapter.isRowAllSharedStories(groupPosition)) break;
            if (adapter.isRowInfrequentStories(groupPosition)) break;
            if (adapter.isRowSavedSearches(groupPosition)) break;
            inflater.inflate(R.menu.context_folder, menu);

            if (adapter.isRowAllStories(groupPosition)) {
                menu.removeItem(R.id.menu_mute_folder);
                menu.removeItem(R.id.menu_unmute_folder);
                menu.removeItem(R.id.menu_delete_folder);
                menu.removeItem(R.id.menu_rename_folder);
            }

			break;

		case ExpandableListView.PACKED_POSITION_TYPE_CHILD:
            if (adapter.isRowSavedStories(groupPosition)) break;
            if (currentState == StateFilter.SAVED) break;
			inflater.inflate(R.menu.context_feed, menu);
            if (adapter.isRowAllSharedStories(groupPosition)) {
                // social feeds
                menu.removeItem(R.id.menu_delete_feed);
                menu.removeItem(R.id.menu_choose_folders);
                menu.removeItem(R.id.menu_unmute_feed);
                menu.removeItem(R.id.menu_mute_feed);
                menu.removeItem(R.id.menu_notifications);
                menu.removeItem(R.id.menu_instafetch_feed);
                menu.removeItem(R.id.menu_intel);
                menu.removeItem(R.id.menu_rename_feed);
                menu.removeItem(R.id.menu_delete_saved_search);
            } else if (adapter.isRowSavedSearches(groupPosition)) {
                menu.removeItem(R.id.menu_mark_feed_as_read);
                menu.removeItem(R.id.menu_delete_feed);
                menu.removeItem(R.id.menu_unfollow);
                menu.removeItem(R.id.menu_choose_folders);
                menu.removeItem(R.id.menu_rename_feed);
                menu.removeItem(R.id.menu_notifications);
                menu.removeItem(R.id.menu_mute_feed);
                menu.removeItem(R.id.menu_unmute_feed);
                menu.removeItem(R.id.menu_instafetch_feed);
                menu.removeItem(R.id.menu_intel);
            } else {
                // normal feeds
                menu.removeItem(R.id.menu_unfollow);
                menu.removeItem(R.id.menu_delete_saved_search);

                Feed feed = adapter.getFeed(groupPosition, childPosition);
                if (feed.active) {
                    menu.removeItem(R.id.menu_unmute_feed);
                } else {
                    menu.removeItem(R.id.menu_mute_feed);
                }
                if (FeedExt.isAndroidNotifyUnread(feed)) {
                    menu.findItem(R.id.menu_notifications_disable).setChecked(false);
                    menu.findItem(R.id.menu_notifications_unread).setChecked(true);
                    menu.findItem(R.id.menu_notifications_focus).setChecked(false);
                } else if (FeedExt.isAndroidNotifyFocus(feed)) {
                    menu.findItem(R.id.menu_notifications_disable).setChecked(false);
                    menu.findItem(R.id.menu_notifications_unread).setChecked(false);
                    menu.findItem(R.id.menu_notifications_focus).setChecked(true);
                } else {
                    menu.findItem(R.id.menu_notifications_disable).setChecked(true);
                    menu.findItem(R.id.menu_notifications_unread).setChecked(false);
                    menu.findItem(R.id.menu_notifications_focus).setChecked(false);
                }
            }
			break;
		}
	}

    @Override
	public boolean onContextItemSelected(MenuItem item) {
        if (item.getItemId() == R.id.menu_notifications) {
            // this means the notifications menu has been opened, but this is our one chance to see the list position
            // and get the ID of the feed for which the menu was opened. (no packed pos when the submenu is tapped)
            ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) item.getMenuInfo();
            int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
            int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);
            lastMenuFeed = adapter.getFeed(groupPosition, childPosition);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_disable) {
            feedUtils.disableNotifications(getActivity(), lastMenuFeed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_focus) {
            feedUtils.enableFocusNotifications(getActivity(), lastMenuFeed);
            return true;
        }
        if (item.getItemId() == R.id.menu_notifications_unread) {
            feedUtils.enableUnreadNotifications(getActivity(), lastMenuFeed);
            return true;
        }
		ExpandableListView.ExpandableListContextMenuInfo info = (ExpandableListView.ExpandableListContextMenuInfo) item.getMenuInfo();
        int childPosition = ExpandableListView.getPackedPositionChild(info.packedPosition);
        int groupPosition = ExpandableListView.getPackedPositionGroup(info.packedPosition);

		if (item.getItemId() == R.id.menu_delete_feed || item.getItemId() == R.id.menu_unfollow) {
			DialogFragment deleteFeedFragment;
            if (adapter.isRowAllSharedStories(groupPosition)) {
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getSocialFeed(groupPosition, childPosition));
            } else {
                String folderName = adapter.getGroupFolderName(groupPosition);
                deleteFeedFragment = DeleteFeedFragment.newInstance(adapter.getFeed(groupPosition, childPosition), folderName);
            }
			deleteFeedFragment.show(getParentFragmentManager(), "dialog");
			return true;
		} else if (item.getItemId() == R.id.menu_mark_feed_as_read) {
            FeedSet fs = adapter.getChild(groupPosition, childPosition);
            markFeedsAsRead(fs);
			return true;
		} else if (item.getItemId() == R.id.menu_mark_folder_as_read) {
            FeedSet fs = adapter.getGroup(groupPosition);
            markFeedsAsRead(fs);
			return true;
		} else if (item.getItemId() == R.id.menu_choose_folders) {
            Feed feed = adapter.getFeed(groupPosition, childPosition);
            if (feed != null) {
                DialogFragment chooseFoldersFragment = ChooseFoldersFragment.newInstance(feed);
                chooseFoldersFragment.show(getParentFragmentManager(), "dialog");
            }
        } else if (item.getItemId() == R.id.menu_rename_feed) {
            Feed feed = adapter.getFeed(groupPosition, childPosition);
            if (feed != null) {
                DialogFragment renameFeedFragment = RenameDialogFragment.newFeedInstance(feed.feedId, feed.title);
                renameFeedFragment.show(getParentFragmentManager(), "dialog");
            }
        } else if (item.getItemId() == R.id.menu_mute_feed) {
            Set<String> feedIds = new HashSet<String>();
            feedIds.add(adapter.getFeed(groupPosition, childPosition).feedId);
            feedUtils.muteFeeds(getActivity(), feedIds);
        } else if (item.getItemId() == R.id.menu_unmute_feed) {
            Set<String> feedIds = new HashSet<String>();
            feedIds.add(adapter.getFeed(groupPosition, childPosition).feedId);
            feedUtils.unmuteFeeds(getActivity(), feedIds);
        } else if (item.getItemId() == R.id.menu_mute_folder) {
            feedUtils.muteFeeds(getActivity(), adapter.getAllFeedsForFolder(groupPosition));
        } else if (item.getItemId() == R.id.menu_unmute_folder) {
            feedUtils.unmuteFeeds(getActivity(), adapter.getAllFeedsForFolder(groupPosition));
        } else if (item.getItemId() == R.id.menu_instafetch_feed) {
            feedUtils.instaFetchFeed(getActivity(), adapter.getFeed(groupPosition, childPosition).feedId);
        } else if (item.getItemId() == R.id.menu_intel) {
            FeedIntelTrainerFragment intelFrag = FeedIntelTrainerFragment.newInstance(adapter.getFeed(groupPosition, childPosition), adapter.getChild(groupPosition, childPosition));
            intelFrag.show(getParentFragmentManager(), FeedIntelTrainerFragment.class.getName());
        } else if (item.getItemId() == R.id.menu_delete_saved_search) {
		    SavedSearch savedSearch = adapter.getSavedSearch(childPosition);
		    if (savedSearch != null) {
                DialogFragment deleteFeedFragment = DeleteFeedFragment.newInstance(savedSearch);
                deleteFeedFragment.show(getParentFragmentManager(), "dialog");
            }
		} else if (item.getItemId() == R.id.menu_delete_folder) {
		    Folder folder = adapter.getGroupFolder(groupPosition);
		    String folderParentName = folder.getFirstParentName();
            DeleteFolderDialogFragment deleteFolderFragment = DeleteFolderDialogFragment.newInstance(folder.name, folderParentName);
		    deleteFolderFragment.show(getParentFragmentManager(), deleteFolderFragment.getTag());
        } else if (item.getItemId() == R.id.menu_rename_folder) {
		    Folder folder = adapter.getGroupFolder(groupPosition);
            String folderParentName = folder.getFirstParentName();
            RenameDialogFragment renameDialogFragment = RenameDialogFragment.newFolderInstance(folder.name, folderParentName);
            renameDialogFragment.show(getParentFragmentManager(), renameDialogFragment.getTag());
        }

		return super.onContextItemSelected(item);
	}

    private void markFeedsAsRead(FeedSet fs) {
        feedUtils.markRead(((NbActivity) getActivity()), fs, null, null, R.array.mark_all_read_options);
        adapter.lastFeedViewedId = fs.getSingleFeed();
        adapter.lastFolderViewed = fs.getFolderName();
    }

	public void changeState(StateFilter state) {
		currentState = state;
        prefsRepo.setStateFilter(state);
        adapter.changeState(state);
		hasUpdated();
	}

    public void clearRecents() {
        adapter.lastFeedViewedId = null;
        adapter.lastFolderViewed = null;
    }

    public void forceShowFeed(String feedId) {
        adapter.lastFeedViewedId = feedId;
        adapter.lastFolderViewed = null;
    }

    public void setSearchQuery(String q) {
        applySearchQuery(q, true);
    }

    public String getSearchQuery() {
        return adapter.activeSearchQuery;
    }

    private void applySearchQuery(@Nullable String query, boolean syncField) {
        String normalizedQuery = normalizeSearchQuery(query);
        boolean shouldRestoreFocus = searchHeaderBinding != null && searchHeaderBinding.inputSearchQuery.hasFocus();
        int selectionEnd = shouldRestoreFocus ? searchHeaderBinding.inputSearchQuery.getSelectionEnd() : -1;
        if (!TextUtils.equals(adapter.activeSearchQuery, normalizedQuery)) {
            adapter.activeSearchQuery = normalizedQuery;
            adapter.forceRecount();
            pushUnreadCounts();
            checkOpenFolderPreferences();
        }
        if (syncField) {
            syncSearchField(normalizedQuery);
        }
        if (shouldRestoreFocus) {
            restoreSearchFieldFocus(normalizedQuery, selectionEnd);
        }
    }

    @Nullable
    private String normalizeSearchQuery(@Nullable CharSequence query) {
        if (query == null) {
            return null;
        }
        String normalizedQuery = query.toString().trim();
        return normalizedQuery.isEmpty() ? null : normalizedQuery;
    }

    private void syncSearchField(@Nullable String query) {
        if (searchHeaderBinding == null) {
            return;
        }

        String displayQuery = (query == null) ? "" : query;
        updateSearchClearButton(displayQuery);
        if (TextUtils.equals(searchHeaderBinding.inputSearchQuery.getText(), displayQuery)) {
            return;
        }

        isSyncingSearchField = true;
        searchHeaderBinding.inputSearchQuery.setText(displayQuery);
        searchHeaderBinding.inputSearchQuery.setSelection(displayQuery.length());
        isSyncingSearchField = false;
    }

    private void updateSearchClearButton(@Nullable CharSequence query) {
        if (searchHeaderBinding == null) {
            return;
        }

        boolean hasQuery = !TextUtils.isEmpty(query);
        searchHeaderBinding.clearSearchQuery.setVisibility(hasQuery ? View.VISIBLE : View.GONE);
    }

    private void restoreSearchFieldFocus(@Nullable String query, int selectionEnd) {
        if (searchHeaderBinding == null) {
            return;
        }

        String displayQuery = (query == null) ? "" : query;
        int safeSelectionEnd = Math.max(0, Math.min(selectionEnd, displayQuery.length()));
        searchHeaderBinding.inputSearchQuery.post(() -> {
            if (searchHeaderBinding == null) {
                return;
            }
            searchHeaderBinding.inputSearchQuery.requestFocus();
            searchHeaderBinding.inputSearchQuery.setSelection(safeSelectionEnd);
            InputMethodManager inputMethodManager =
                    (InputMethodManager) requireContext().getSystemService(Context.INPUT_METHOD_SERVICE);
            if (inputMethodManager != null) {
                inputMethodManager.showSoftInput(searchHeaderBinding.inputSearchQuery, InputMethodManager.SHOW_IMPLICIT);
            }
        });
    }

    /**
     * Every time unread counts are updated in the adapter, ping the Main activity with
     * the new data.  It is, unfortunately, quite expensive to compute given the current
     * DB model, so having Main also load it would cause some lag.
     */
    public void pushUnreadCounts() {
        ((Main) getActivity()).updateUnreadCounts((adapter.totalNeutCount+adapter.totalSocialNeutCount), (adapter.totalPosCount+adapter.totalSocialPosiCount));
        ((Main) getActivity()).updateFeedCount(adapter.lastFeedCount);
        com.newsblur.util.Log.d(this, "showing " + adapter.lastFeedCount + " feeds");
    }

    private void restoreListStateIfReady() {
        if (pendingListState == null || hasRestoredListState || binding == null || !firstCursorSeenYet) {
            return;
        }

        binding.folderfeedList.post(() -> {
            if (pendingListState == null || hasRestoredListState || binding == null) {
                return;
            }
            binding.folderfeedList.onRestoreInstanceState(pendingListState);
            hasRestoredListState = true;
            pendingListState = null;
        });
    }

	@Override
    public boolean onGroupClick(ExpandableListView list, View group, int groupPosition, long id) {
        if (adapter.isRowSavedSearches(groupPosition)) {
            // group not clickable
            return true;
        }

        FeedSet fs = adapter.getGroup(groupPosition);
        Intent i;
        if (adapter.isRowAllStories(groupPosition)) {
            if (currentState == StateFilter.SAVED) {
                // the existence of this row in saved mode is something of a framework artifact and may
                // confuse users. redirect them to the activity corresponding to what they will actually see
                i = new Intent(getActivity(), SavedStoriesItemsList.class);
            } else {
			    i = new Intent(getActivity(), AllStoriesItemsList.class);
            }
        } else if (adapter.isRowDailyBriefing(groupPosition)) {
            i = new Intent(getActivity(), DailyBriefingActivity.class);
        } else if (adapter.isRowGlobalSharedStories(groupPosition)) {
            i = new Intent(getActivity(), GlobalSharedStoriesItemsList.class);
        } else if (adapter.isRowAllSharedStories(groupPosition)) {
            i = new Intent(getActivity(), AllSharedStoriesItemsList.class);
        } else if (adapter.isRowInfrequentStories(groupPosition)) {
            i = new Intent(getActivity(), InfrequentItemsList.class);
        } else if (adapter.isRowReadStories(groupPosition)) {
            i = new Intent(getActivity(), ReadStoriesItemsList.class);
        } else if (adapter.isRowSavedStories(groupPosition)) {
            i = new Intent(getActivity(), SavedStoriesItemsList.class);
        } else {
            i = new Intent(getActivity(), FolderItemsList.class);
            String canonicalFolderName = adapter.getGroupFolderName(groupPosition);
            SessionDataSource sessionDataSource = getSessionData(fs, canonicalFolderName, null);
            i.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, canonicalFolderName);
            i.putExtra(ItemsList.EXTRA_SESSION_DATA, sessionDataSource);
            adapter.lastFeedViewedId = null;
            adapter.lastFolderViewed = canonicalFolderName;
        }
        i.putExtra(ItemsList.EXTRA_FEED_SET, fs);
        startActivity(i);

        // by default, ExpandableListViews open/close groups when they are clicked. we want to
        // only do this when the expando is clicked, so we eat all onGroupClick events and
        // set an onClick listeneron the expandos  when creating each group view that will
        // perform the expand/collapse functionality
        return true;
	}

    @Override
    public void onGroupExpand(int groupPosition) {
        // these shouldn't ever be collapsible
        if (adapter.isRowRootFolder(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;

        String flatGroupName = adapter.getGroupUniqueName(groupPosition);
        // save the expanded preference, since the widget likes to forget it
        prefsRepo.putBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, true);

        if (!adapter.isNormalFolder(groupPosition)) return;

        // trigger display/hide of sub-folders
        adapter.setFolderClosed(flatGroupName, false);
        // re-check open/closed state of sub folders, since the list will have forgot them
        checkOpenFolderPreferences();
    }

    @Override
    public void onGroupCollapse(int groupPosition) {
        // these shouldn't ever be collapsible
        if (adapter.isRowRootFolder(groupPosition)) return;
        if (adapter.isRowReadStories(groupPosition)) return;

        String flatGroupName = adapter.getGroupUniqueName(groupPosition);
        // save the collapsed preference, since the widget likes to forget it
        prefsRepo.putBoolean(AppConstants.FOLDER_PRE + "_" + flatGroupName, false);

        if (!adapter.isNormalFolder(groupPosition)) return;

        // trigger display/hide of sub-folders
        adapter.setFolderClosed(flatGroupName, true);
    }

	@Override
    public boolean onChildClick(ExpandableListView list, View childView, int groupPosition, int childPosition, long id) {
        feedUtils.currentFolderName = null;
        FeedSet fs = adapter.getChild(groupPosition, childPosition);
		if (adapter.isRowAllSharedStories(groupPosition)) {
            SocialFeed socialFeed = adapter.getSocialFeed(groupPosition, childPosition);
			Intent intent = new Intent(getActivity(), SocialFeedItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
			intent.putExtra(SocialFeedItemsList.EXTRA_SOCIAL_FEED, socialFeed);
			getActivity().startActivity(intent);
        } else if (adapter.isRowSavedStories(groupPosition)) {
            Intent intent = new Intent(getActivity(), SavedStoriesItemsList.class);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
			getActivity().startActivity(intent);
		} else if (adapter.isRowSavedSearches(groupPosition)) {
		    openSavedSearch(adapter.getSavedSearch(childPosition));
        } else {
            Feed feed = adapter.getFeed(groupPosition, childPosition);
            // NB: FeedItemsList needs the name of the containing folder, but this is not the same as setting
            // a folder name on the FeedSet and making it into a folder-type set.  it is just a single feed,
            // and the folder name is a bit of metadata needed by the UI/API
			String folderName = adapter.getGroupFolderName(groupPosition);
			if(folderName == null || folderName.equals(AppConstants.ROOT_FOLDER)){
                feedUtils.currentFolderName = null;
            }else{

                feedUtils.currentFolderName = folderName;
            }
            SessionDataSource sessionDataSource = getSessionData(fs, folderName, feed);
            if (adapter.isTryFeed(groupPosition, childPosition)) {
                FeedItemsList.startTryFeedActivity(getActivity(), feed);
            } else {
			    FeedItemsList.startActivity(getActivity(), fs, feed, folderName, sessionDataSource);
            }
            adapter.lastFeedViewedId = feed.feedId;
            adapter.lastFolderViewed = null;
		}
		return true;
	}

	private void checkAccountFeedsLimit() {
        if (hasShownFeedsLimitDialog) return;
        new Handler().postDelayed(() -> {
            if (getActivity() != null && adapter.totalActiveFeedCount > AppConstants.FREE_ACCOUNT_SITE_LIMIT && !prefsRepo.hasSubscription()) {
                hasShownFeedsLimitDialog = true;
                Intent intent = new Intent(getActivity(), MuteConfig.class);
                startActivity(intent);
            }
        }, 2000);
    }

    private void openSavedSearch(SavedSearch savedSearch) {
        Intent intent = null;
        FeedSet fs = null;
        String feedId = savedSearch.feedId;
        if (feedId.equals("river:")) {
            // all site stories
            intent = new Intent(getActivity(), AllStoriesItemsList.class);
            fs = FeedSet.allFeeds();
        } else if (feedId.equals("river:infrequent")) {
            // infrequent stories
            intent = new Intent(getActivity(), InfrequentItemsList.class);
            fs = FeedSet.infrequentFeeds();
        } else if (feedId.startsWith("river:")) {
            intent = new Intent(getActivity(), FolderItemsList.class);
            String folderName = feedId.replace("river:", "");
            fs = dbHelper.feedSetFromFolderName(folderName);
            intent.putExtra(FolderItemsList.EXTRA_FOLDER_NAME, folderName);
        } else if (feedId.equals("read")) {
            intent = new Intent(getActivity(), ReadStoriesItemsList.class);
            fs = FeedSet.allRead();
        } else if (feedId.equals("starred")) {
            intent = new Intent(getActivity(), SavedStoriesItemsList.class);
            fs = FeedSet.allSaved();
        } else if (feedId.startsWith("starred:")) {
            intent = new Intent(getActivity(), SavedStoriesItemsList.class);
            fs = FeedSet.singleSavedTag(feedId.replace("starred:", ""));
        } else if (feedId.startsWith("feed:")) {
            intent = new Intent(getActivity(), FeedItemsList.class);
            String cleanFeedId = feedId.replace("feed:", "");
            Feed feed = feedUtils.getFeed(cleanFeedId);
            fs = FeedSet.singleFeed(cleanFeedId);
            intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
        } else if (feedId.startsWith("social:")) {
            intent = new Intent(getActivity(), SocialFeedItemsList.class);
            String cleanFeedId = feedId.replace("social:", "");
            fs = FeedSet.singleFeed(cleanFeedId);
            Feed feed = feedUtils.getFeed(cleanFeedId);
            intent.putExtra(FeedItemsList.EXTRA_FEED, feed);
        }

        if (intent != null) {
            fs.setSearchQuery(savedSearch.query);
            intent.putExtra(ItemsList.EXTRA_FEED_SET, fs);
            startActivity(intent);
        }
    }

    public void setListTextSize(ListTextSize listTextSize) {
        prefsRepo.setListTextSize(listTextSize.getSize());
        if (adapter != null) {
            adapter.setTextSize(listTextSize.getSize());
            adapter.notifyDataSetChanged();
        }
    }

    public void setSpacingStyle(SpacingStyle spacingStyle) {
        prefsRepo.setSpacingStyle(spacingStyle);
        if (adapter != null) {
            adapter.setSpacingStyle(spacingStyle);
            adapter.notifyDataSetChanged();
        }
    }

    @Nullable
    private SessionDataSource getSessionData(FeedSet fs, String folderName, @Nullable Feed feed) {
        if (prefsRepo.loadNextOnMarkRead()) {
            Session activeSession = new Session(fs, folderName, feed);
            return adapter.buildSessionDataSource(activeSession);
        }
        return null;
    }

    @Override
    public void onSaveInstanceState(@NonNull Bundle outState) {
        super.onSaveInstanceState(outState);
        if (binding != null) {
            outState.putParcelable(BUNDLE_LIST_STATE, binding.folderfeedList.onSaveInstanceState());
        }
    }
}
