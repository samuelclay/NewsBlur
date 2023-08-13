package com.newsblur.fragment;

import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.os.Bundle;

import androidx.appcompat.app.AlertDialog;
import androidx.fragment.app.DialogFragment;
import android.view.Gravity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.View.OnClickListener;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.CheckBox;
import android.widget.ListAdapter;

import com.newsblur.R;
import com.newsblur.database.BlurDatabaseHelper;
import com.newsblur.databinding.DialogChoosefoldersBinding;
import com.newsblur.domain.Feed;
import com.newsblur.domain.Folder;
import com.newsblur.util.FeedUtils;

import javax.inject.Inject;

import dagger.hilt.android.AndroidEntryPoint;

@AndroidEntryPoint
public class ChooseFoldersFragment extends DialogFragment {

    @Inject
    BlurDatabaseHelper dbHelper;

    @Inject
    FeedUtils feedUtils;

	private Feed feed;

    public static ChooseFoldersFragment newInstance(Feed feed) {
		ChooseFoldersFragment fragment = new ChooseFoldersFragment();
		Bundle args = new Bundle();
		args.putSerializable("feed", feed);
		fragment.setArguments(args);
		return fragment;
	}

	@Override
	public Dialog onCreateDialog(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		feed = (Feed) getArguments().getSerializable("feed");
        final List<Folder> folders = dbHelper.getFolders();
        Collections.sort(folders, Folder.FolderComparator);

        final Set<String> newFolders = new HashSet<String>();
        final Set<String> oldFolders = new HashSet<String>();
        for (Folder folder : folders) {
            if (folder.feedIds.contains(feed.feedId)) {
                newFolders.add(folder.name);
                oldFolders.add(folder.name);
            }
        }

        final Activity activity = getActivity();
        LayoutInflater inflater = LayoutInflater.from(activity);
        View v = inflater.inflate(R.layout.dialog_choosefolders, null);
        DialogChoosefoldersBinding binding = DialogChoosefoldersBinding.bind(v);

        AlertDialog.Builder builder = new AlertDialog.Builder(activity);
        builder.setTitle(String.format(getResources().getString(R.string.title_choose_folders), feed.title));
        builder.setView(v);

        builder.setNegativeButton(R.string.alert_dialog_cancel, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                ChooseFoldersFragment.this.dismiss();
            }
        });
        builder.setPositiveButton(R.string.dialog_folders_save, new DialogInterface.OnClickListener() {
            @Override
            public void onClick(DialogInterface dialogInterface, int i) {
                feedUtils.moveFeedToFolders(activity, feed.feedId, newFolders, oldFolders);
                ChooseFoldersFragment.this.dismiss();
            }
        });

        ListAdapter adapter = new ArrayAdapter<Folder>(getActivity(), R.layout.row_choosefolders, R.id.choosefolders_foldername, folders) {
            @Override
            public View getView(final int position, View convertView, ViewGroup parent) {
                View v = super.getView(position, convertView, parent);
                CheckBox row = (CheckBox) v.findViewById(R.id.choosefolders_foldername);
                if (position == 0) {
                    row.setText(R.string.top_level);
                }
                row.setChecked(folders.get(position).feedIds.contains(feed.feedId));
                row.setOnClickListener(new OnClickListener() {
                    @Override
                    public void onClick(View v) {
                        CheckBox row = (CheckBox) v;
                        if (row.isChecked()) {
                            folders.get(position).feedIds.add(feed.feedId);
                            newFolders.add(folders.get(position).name);
                        } else {
                            folders.get(position).feedIds.remove(feed.feedId);
                            newFolders.remove(folders.get(position).name);
                        }
                    }
                });
                return v;
            }
        };
        binding.chooseFoldersList.setAdapter(adapter);

        Dialog dialog = builder.create();
        dialog.getWindow().getAttributes().gravity = Gravity.BOTTOM;
        return dialog;
	}

}

