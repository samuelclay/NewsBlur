//
//  GridDetailViewController.swift
//  NewsBlur
//
//  Created by David Sinclair on 2022-08-19.
//  Copyright © 2022 NewsBlur. All rights reserved.
//

import UIKit

/// A view controller to manage the Grid layout.
class GridDetailViewController: UIViewController {
    /// Returns the shared app delegate.
    var appDelegate: NewsBlurAppDelegate {
        return NewsBlurAppDelegate.shared()
    }
    
    @IBOutlet var collectionView: UICollectionView!
    
    enum SectionLayoutKind: Int, CaseIterable {
        /// Feed cells before the story.
        case feedBeforeStory
        
        /// The selected story.
        case selectedStory
        
        /// Feed cells after the story.
        case feedAfterStory
    }
    
    var feedColumns: Int {
        guard let pref = UserDefaults.standard.string(forKey: "grid_columns"), let columns = Int(pref) else {
            return 4
        }
        
        return columns
    }
    
    var dataSource: UICollectionViewDiffableDataSource<SectionLayoutKind, Int>! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionView.collectionViewLayout = createLayout()
        configureDataSource()
    }
    
    @objc func reload() {
        configureDataSource()
    }
}

extension GridDetailViewController {
    func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int,
                                                            layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            
            guard let sectionLayoutKind = SectionLayoutKind(rawValue: sectionIndex) else {
                return nil
            }
            
            let isStory = sectionLayoutKind == .selectedStory
            let columns = isStory ? 1 : self.feedColumns
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10)
            
            let groupHeight = isStory ?
            NSCollectionLayoutDimension.absolute(1000) :
            NSCollectionLayoutDimension.fractionalWidth(0.4)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: groupHeight)
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitem: item, count: columns)
            
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 10, bottom: 0, trailing: 10)
            
            return section
        }
        
        return layout
    }
}

extension GridDetailViewController {
    func configureDataSource() {
        let feedCellRegistration = UICollectionView.CellRegistration<GridFeedCell, Int> { (cell, indexPath, identifier) in
            cell.contentView.backgroundColor = UIColor.red
            cell.contentView.layer.borderColor = UIColor.black.cgColor
            cell.contentView.layer.borderWidth = 1
//            cell.contentView.layer.cornerRadius = SectionLayoutKind(rawValue: indexPath.section)! == .feed ? 8 : 0
            //TODO: 🚧
        }
        
        let storyCellRegistration = UICollectionView.CellRegistration<StoryPagesCollectionCell, Int> { (cell, indexPath, identifier) in
            //TODO: 🚧
            cell.contentView.backgroundColor = UIColor.blue
        }
        
        dataSource = UICollectionViewDiffableDataSource<SectionLayoutKind, Int>(collectionView: collectionView) {
            (collectionView: UICollectionView, indexPath: IndexPath, identifier: Int) -> UICollectionViewCell? in
            return SectionLayoutKind(rawValue: indexPath.section)! == .selectedStory ?
            collectionView.dequeueConfiguredReusableCell(using: storyCellRegistration, for: indexPath, item: identifier) : collectionView.dequeueConfiguredReusableCell(using: feedCellRegistration, for: indexPath, item: identifier)
            
        }
        
        var snapshot = NSDiffableDataSourceSnapshot<SectionLayoutKind, Int>()
        
        if let activeFeed = appDelegate.storiesCollection.activeFeedStories {
            let numberOfStories = activeFeed.count
            let selectedIndex = min(numberOfStories - 1, 8)
            
            snapshot.appendSections(SectionLayoutKind.allCases)
            snapshot.appendItems(Array(0..<selectedIndex - 1), toSection: .feedBeforeStory)
            snapshot.appendItems([selectedIndex], toSection: .selectedStory)
            snapshot.appendItems(Array(selectedIndex + 1..<numberOfStories), toSection: .feedAfterStory)
        }
        
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

extension GridDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
    }
}
