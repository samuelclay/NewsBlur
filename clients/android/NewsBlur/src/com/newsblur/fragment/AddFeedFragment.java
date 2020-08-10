package com.newsblur.fragment;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.Dialog;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.DialogFragment;
import android.support.v7.widget.DividerItemDecoration;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Toast;

import com.newsblur.R;
import com.newsblur.activity.Main;
import com.newsblur.databinding.DialogAddFeedBinding;
import com.newsblur.databinding.RowAddFeedFolderBinding;
import com.newsblur.domain.Folder;
import com.newsblur.network.APIManager;
import com.newsblur.network.domain.AddFeedResponse;
import com.newsblur.network.domain.NewsBlurResponse;
import com.newsblur.service.NBSyncService;
import com.newsblur.util.AppConstants;
import com.newsblur.util.FeedUtils;
import com.newsblur.util.UIUtils;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class AddFeedFragment extends DialogFragment {

    private static final String FEED_URI = "feed_url";
    private static final String FEED_NAME = "feed_name";
    private DialogAddFeedBinding binding;

    public static AddFeedFragment newInstance(String feedUri, String feedName) {
        AddFeedFragment frag = new AddFeedFragment();
        Bundle args = new Bundle();
        args.putString(FEED_URI, feedUri);
        args.putString(FEED_NAME, feedName);
        frag.setArguments(args);
        return frag;
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        final Activity activity = getActivity();
        final APIManager apiManager = new APIManager(activity);

        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_add_feed, null);
        binding = DialogAddFeedBinding.bind(v);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle("Choose folder for " + getArguments().getString(FEED_NAME));
        builder.setView(v);

        AddFeedAdapter adapter = new AddFeedAdapter(new OnFolderClickListener() {
            @Override
            public void onItemClick(Folder folder) {
                addFeed(activity, apiManager, folder.name);
            }
        });

        binding.textAddFolderTitle.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (binding.containerAddFolder.getVisibility() == View.GONE) {
                    binding.containerAddFolder.setVisibility(View.VISIBLE);
                } else {
                    binding.containerAddFolder.setVisibility(View.GONE);
                }
            }
        });
        binding.icCreateFolder.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (binding.inputFolderName.getText().length() == 0) {
                    Toast.makeText(activity, R.string.add_folder_name, Toast.LENGTH_SHORT).show();
                } else {
                    addFeedToNewFolder(activity, apiManager, binding.inputFolderName.getText().toString());
                }
            }
        });

        binding.recyclerViewFolders.addItemDecoration(new DividerItemDecoration(activity, LinearLayoutManager.VERTICAL));
        binding.recyclerViewFolders.setAdapter(adapter);
        adapter.setFolders(FeedUtils.dbHelper.getFolders());
        return builder.create();
    }

    private void addFeedToNewFolder(final Activity activity, final APIManager apiManager, final String folderName) {
        binding.icCreateFolder.setVisibility(View.GONE);
        binding.progressBar.setVisibility(View.VISIBLE);
        binding.inputFolderName.setEnabled(false);

        new AsyncTask<Void, Void, NewsBlurResponse>() {
            @Override
            protected NewsBlurResponse doInBackground(Void... voids) {
                return apiManager.addFolder(folderName);
            }

            @Override
            protected void onPostExecute(NewsBlurResponse newsBlurResponse) {
                super.onPostExecute(newsBlurResponse);
                binding.inputFolderName.setEnabled(true);

                if (!newsBlurResponse.isError()) {
                    binding.containerAddFolder.setVisibility(View.GONE);
                    binding.inputFolderName.getText().clear();
                    addFeed(activity, apiManager, folderName);
                } else {
                    UIUtils.safeToast(activity, R.string.add_folder_error, Toast.LENGTH_SHORT);
                }
            }
        }.execute();
    }

    private void addFeed(final Activity activity, final APIManager apiManager, @Nullable final String folderName) {
        binding.textSyncStatus.setVisibility(View.VISIBLE);
        new AsyncTask<Void, Void, AddFeedResponse>() {
            @Override
            protected AddFeedResponse doInBackground(Void... voids) {
                ((AddFeedProgressListener) activity).addFeedStarted();
                String feedUrl = getArguments().getString(FEED_URI);
                return apiManager.addFeed(feedUrl, folderName);
            }

            @Override
            protected void onPostExecute(AddFeedResponse result) {
                super.onPostExecute(result);
                binding.textSyncStatus.setVisibility(View.GONE);
                final Intent intent = new Intent(activity, Main.class);
                intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                if (!result.isError()) {
                    // trigger a sync when we return to Main so that the new feed will show up
                    NBSyncService.forceFeedsFolders();
                    intent.putExtra(Main.EXTRA_FORCE_SHOW_FEED_ID, result.feed.feedId);
                } else {
                    UIUtils.safeToast(activity, R.string.add_feed_error, Toast.LENGTH_SHORT);
                }
                activity.startActivity(intent);
                activity.finish();
                AddFeedFragment.this.dismiss();
            }
        }.execute();
    }

    private static class AddFeedAdapter extends RecyclerView.Adapter<AddFeedAdapter.FolderViewHolder> {

        AddFeedAdapter(OnFolderClickListener listener) {
            this.listener = listener;
        }

        private final List<Folder> folders = new ArrayList<>();
        private OnFolderClickListener listener;

        @NonNull
        @Override
        public AddFeedAdapter.FolderViewHolder onCreateViewHolder(@NonNull ViewGroup viewGroup, int position) {
            View view = LayoutInflater.from(viewGroup.getContext()).inflate(R.layout.row_add_feed_folder, viewGroup, false);
            return new FolderViewHolder(view);
        }

        @Override
        public void onBindViewHolder(@NonNull AddFeedAdapter.FolderViewHolder viewHolder, int position) {
            final Folder folder = folders.get(position);
            if (folder.name.equals(AppConstants.ROOT_FOLDER)) {
                viewHolder.binding.textFolderTitle.setText(R.string.top_level);
            } else {
                viewHolder.binding.textFolderTitle.setText(folder.flatName());
            }
            viewHolder.itemView.setOnClickListener(new View.OnClickListener() {
                @Override
                public void onClick(View v) {
                    listener.onItemClick(folder);
                }
            });
        }

        @Override
        public int getItemCount() {
            return folders.size();
        }

        public void setFolders(List<Folder> folders) {
            Collections.sort(folders, Folder.FolderComparator);
            this.folders.clear();
            this.folders.addAll(folders);
            this.notifyDataSetChanged();
        }

        static class FolderViewHolder extends RecyclerView.ViewHolder {

            public RowAddFeedFolderBinding binding;

            public FolderViewHolder(@NonNull View itemView) {
                super(itemView);
                binding = RowAddFeedFolderBinding.bind(itemView);
            }
        }
    }

    public interface AddFeedProgressListener {
        void addFeedStarted();
    }

    public interface OnFolderClickListener {
        void onItemClick(Folder folder);
    }
}