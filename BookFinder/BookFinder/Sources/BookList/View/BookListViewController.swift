//
//  BookListViewController.swift
//  BookFinder
//
//  Created by 전소영 on 2022/08/16.
//

import UIKit
import SnapKit
import Then
import RxSwift
import RxCocoa

class BookListViewController: UIViewController {
    private let disposeBag = DisposeBag()
    private let viewModel = BookListViewModel()
    private var bookItems: [BookItem] = []
    private var searchResultCount = 0
    private var isRequesting = false
    
    private let searchController = UISearchController().then {
        $0.searchBar.placeholder = "책 또는 저자를 검색해주세요"
    }

    private let searchResultCountLabel = UILabel().then {
        $0.font = UIFont.setFont(type: .regular, size: 14)
    }

    private let lineView = UIView().then {
        $0.backgroundColor = .lightGray
    }

    private let bookListCollectionViewFlowLayout = UICollectionViewFlowLayout().then {
        $0.scrollDirection = .vertical
        $0.minimumLineSpacing = 4
    }

    private lazy var bookListCollectionView = UICollectionView.init(frame: .zero, collectionViewLayout: bookListCollectionViewFlowLayout).then {
        $0.showsVerticalScrollIndicator = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupSearchController()
        setupCollectionView()
        bindAction()
        bindViewModel()
    }

    private func setupView() {
        view.backgroundColor = .white

        setupSubViews()
        setupConstraints()
    }

    private func setupSubViews() {
        view.addSubviews([searchResultCountLabel, lineView, bookListCollectionView])
    }

    private func setupConstraints() {
        searchResultCountLabel.snp.makeConstraints {
            $0.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(12)
            $0.leading.equalToSuperview().inset(24)
        }

        lineView.snp.makeConstraints {
            $0.top.equalTo(searchResultCountLabel.snp.bottom).offset(6)
            $0.centerX.width.equalToSuperview()
            $0.height.equalTo(0.2)
        }

        bookListCollectionView.snp.makeConstraints {
            $0.top.equalTo(lineView.snp.bottom).offset(6)
            $0.centerX.width.equalToSuperview()
            $0.bottom.equalToSuperview()
        }
    }

    private func setupSearchController() {
        navigationItem.searchController = searchController
        navigationItem.title = "📚BookFinder🔍"
        navigationItem.hidesSearchBarWhenScrolling = false
    }

    private func setupCollectionView() {
        bookListCollectionView.dataSource = self
        bookListCollectionView.delegate = self
        bookListCollectionView.registerCell(cellType: BookListCollectionViewCell.self)
    }

    private func bindAction() {
        searchController.searchBar.searchTextField.rx.controlEvent(.editingDidEndOnExit)
            .bind { [weak self] _ in
                self?.initialize()
                if let searchText = self?.searchController.searchBar.searchTextField.text {
                    print("searchText: \(searchText)")
                    self?.viewModel.action.didSearch.onNext((searchText))
                }
            }
            .disposed(by: self.disposeBag)

        bookListCollectionView.rx.prefetchItems
            .compactMap(\.last?.item)
            .withUnretained(self)
            .bind { [weak self] vc, item in
                if self?.viewModel.isRequestCompleted == false {
                    if let searchText = self?.searchController.searchBar.searchTextField.text,
                       let dataCount = self?.bookItems.count,
                       item >= dataCount - 3,
                       self?.isRequesting == false {
                        self?.viewModel.action.didSearch.onNext((searchText))
                    }
                }
            }
            .disposed(by: self.disposeBag)
    }

    private func bindViewModel() {
        viewModel.state.bookListData
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] result in
                switch result {
                case .success(let bookList):
                    self?.bookItems.append(contentsOf: bookList.items)
                    if self?.searchResultCount == 0 {
                        self?.searchResultCount = bookList.totalItems
                    }
                    self?.searchResultCountLabel.text = "📚 검색 결과: \(self?.searchResultCount ?? 0)개"
                    self?.bookListCollectionView.reloadData()
                case .failure:
                    self?.showAlert(title: "📚 검색 결과 불러올 수 없음", message: "검색 결과를 불러올 수 없으므로 재검색 바랍니다.")
                    self?.searchResultCountLabel.text = nil
                    self?.searchResultCountLabel.isHidden = true
                }
            })
            .disposed(by: disposeBag)
        
        viewModel.state.isRequesting
            .subscribe(onNext: { [weak self] isRequesting in
                self?.isRequesting = isRequesting
                if isRequesting {
                    LoadingActivityIndicatorManager.showLoadingActivityIndicator()
                } else {
                    LoadingActivityIndicatorManager.hideLoadingActivityIndicator()
                }
            })
            .disposed(by: disposeBag)
    }

    private func initialize() {
        viewModel.initialize()
        bookItems = []
        searchResultCount = 0
        searchResultCountLabel.isHidden = false
        bookListCollectionView.contentOffset = .zero
        bookListCollectionView.reloadData()
    }
}

// MARK: UICollectionViewDataSource
extension BookListViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return bookItems.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BookListCollectionViewCell", for: indexPath)
        let bookListCollectionViewCell = cell as? BookListCollectionViewCell
        bookListCollectionViewCell?.setupUI(data: bookItems[indexPath.item])
        
        return cell
    }
}

// MARK: UICollectionViewDelegate
extension BookListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let bookDetailViewController = BookDetailViewController()
        bookDetailViewController.setupUI(data: bookItems[indexPath.item])
        navigationController?.pushViewController(bookDetailViewController, animated: false)
    }
}

// MARK: UICollectionViewDelegateFlowLayout
extension BookListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 100)
    }
}
