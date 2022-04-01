package com.newsblur.viewModel

import androidx.lifecycle.ViewModel
import com.newsblur.network.APIManager
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class ImportExportViewModel
@Inject constructor(apiManager: APIManager) : ViewModel() {

    fun import() {

    }
}