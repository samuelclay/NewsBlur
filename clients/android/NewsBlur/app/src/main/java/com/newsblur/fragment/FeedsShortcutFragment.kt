package com.newsblur.fragment

import android.app.Dialog
import android.os.Bundle
import androidx.appcompat.app.AlertDialog
import androidx.fragment.app.DialogFragment
import com.newsblur.databinding.FeedsShortcutsDialogBinding

class FeedsShortcutFragment : DialogFragment() {

    override fun onCreateDialog(savedInstanceState: Bundle?): Dialog {
        val binding = FeedsShortcutsDialogBinding.inflate(layoutInflater)

        return AlertDialog.Builder(requireContext()).apply {
            setView(binding.root)
            setPositiveButton(android.R.string.ok, null)
        }.create()
    }
}