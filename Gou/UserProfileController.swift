//
//  UserProfileController.swift
//  Humans
//
//  Created by Omar Torres on 9/07/17.
//  Copyright © 2017 OmarTorres. All rights reserved.
//

import UIKit
import Firebase

class UserProfileController: UICollectionViewController, UICollectionViewDelegateFlowLayout {
    
    let loader: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView.init(style: UIActivityIndicatorView.Style.gray)
        indicator.alpha = 1.0
        indicator.center = CGPoint(x: UIScreen.main.bounds.size.width / 2, y: 270) // 250 is the header height + 20
        indicator.startAnimating()
        return indicator
    }()
    
    let messageLabel: UILabel = {
        let ml = UILabel()
        ml.font = UIFont.systemFont(ofSize: 12)
        ml.numberOfLines = 0
        ml.textAlignment = .center
        ml.isHidden = true
        return ml
    }()
    
    var reviewViewModels = [ReviewViewModel]()
    var userViewModel: UserViewModel!
    
    let homeReviewCellId = "homeReviewCellId"
    
    var userId: String?
    var userFullname: String?
    var userImageUrl: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCollectionView()
        subviewsAnchors()
        checkIfReviewsExists()
        fetchUser()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        UIApplication.shared.isStatusBarHidden = true
        navigationController?.tabBarController?.tabBar.isHidden = true
    }
    
    func setupCollectionView() {
        let layout = collectionView?.collectionViewLayout as? UICollectionViewFlowLayout
        layout?.sectionHeadersPinToVisibleBounds = true
        
        collectionView?.contentInset.bottom = 20
        
        navigationController?.isNavigationBarHidden = true
        
        let lightView = UIView()
        lightView.backgroundColor = .white
        collectionView?.backgroundView = lightView
        
        collectionView?.register(UserProfileHeader.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "headerId")
        collectionView?.register(HomeReviewCell.self, forCellWithReuseIdentifier: homeReviewCellId)
        
        NotificationCenter.default.addObserver(self, selector: #selector(showPreviousCV), name: NSNotification.Name(rawValue: "GoToSearchFromProfile"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(showWriteCV), name: NSNotification.Name(rawValue: "GoToWriteCV"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityStatusChanged), name: NSNotification.Name(rawValue: "ReachStatusChanged"), object: nil)
    }
    
    @objc func reachabilityStatusChanged() {
        print("Checking connectivity...")
    }
    
    func subviewsAnchors() {
        view.addSubview(loader)
        view.addSubview(messageLabel)
        
        messageLabel.anchor(top: view.topAnchor, left: view.leftAnchor, bottom: nil, right: view.rightAnchor, paddingTop: 263 , paddingLeft: 10, paddingBottom: 0, paddingRight: 10, width: 0, height: 0) //263 -> 243 is the header height, plus 20
    }
    
    @objc func showWriteCV() {
        let layout = UICollectionViewFlowLayout()
        let writeReviewController = WriteReviewController(collectionViewLayout: layout)
        
        writeReviewController.userReceiverId = userId
        writeReviewController.userReceiverFullname = userFullname
        writeReviewController.userReceiverImageUrl = userImageUrl
        
        let navController = UINavigationController(rootViewController: writeReviewController)
        present(navController, animated: true, completion: nil)
    }
    
    @objc func showPreviousCV() {
        _ = navigationController?.popViewController(animated: true)
        navigationController?.isNavigationBarHidden = false
    }
    
    func setupMessageLabel() {
        guard let nameFont = UIFont(name: "SFUIDisplay-Semibold", size: 14) else { return }
        guard let messageFont = UIFont(name: "SFUIDisplay-Regular", size: 14) else { return }
        
        guard let userName = self.userFullname else { return }
        let attributedText = NSMutableAttributedString(string: userName, attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.font): nameFont]))
        
        attributedText.append(NSAttributedString(string: " todavía no tiene reseñas 😮.\n ¡Déjale una! ", attributes: convertToOptionalNSAttributedStringKeyDictionary([convertFromNSAttributedStringKey(NSAttributedString.Key.font): messageFont])))
        
        self.messageLabel.attributedText = attributedText
    }
    
    fileprivate func checkIfReviewsExists() {
        Database.database().reference().child("users").child(userId!).child("reviewsCount").observe(.value, with: { (snapshot) in
            let value = snapshot.value as! Int
            if value == 0 {
                print("No hay reviews")
                self.messageLabel.isHidden = false
                self.loader.stopAnimating()
                self.setupMessageLabel()
                
            } else {
                print("Sí hay reviews")
            }
        }) { (err) in
            print("Failed to check if reviews exists for the user:", err)
        }
        
    }
    
    fileprivate func fetchOrderedReviews() {
        let uid = userViewModel.uid
        let ref = Database.database().reference().child("reviews").child(uid)
        
        //perhaps later on we'll implement some pagination of data
        ref.queryOrdered(byChild: "creationDate").observe(.childAdded, with: { (snapshot) in
            guard let dictionary = snapshot.value as? [String: Any] else { return }
            
            guard let user = self.userViewModel else { return }
            
            let review = Review(user: user, dictionary: dictionary)
            let finalReview = ReviewViewModel(user: user, review: review)
            self.reviewViewModels.insert(finalReview, at: 0)
            
            self.collectionView?.reloadData()
            
            self.loader.stopAnimating()
            
        }) { (err) in
            print("Failed to fetch ordered reviews:", err)
        }
    }
    
    fileprivate func fetchUser() {
        
        // Check for internet connection
        if (reachability?.isReachable)! {
            
            let uid = userId ?? (Auth.auth().currentUser?.uid ?? "")
            
            Database.fetchUserWithUID(uid: uid) { (user) in
                self.userViewModel = user
                self.navigationItem.title = self.userViewModel.fullname
                
                self.collectionView?.reloadData()
                
                self.fetchOrderedReviews()
            }
        } else {
            self.loader.stopAnimating()
            
            let alert = UIAlertController(title: "Error", message: "Tu conexión a internet está fallando. 🤔 Intenta de nuevo.", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "Ok", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func showArrow() {
        let sheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        sheetController.addAction(UIAlertAction(title: "Reportar", style: .destructive, handler: { (_) in
            let alert = UIAlertController(title: "", message: "Revisaremos tu reporte. 🤔", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "¡Gracias!", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))
        
        sheetController.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
        
        present(sheetController, animated: true, completion: nil)
    }
    
    @objc func blockUser() {
        let sheetController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        sheetController.addAction(UIAlertAction(title: "Bloquear usuario", style: .destructive, handler: { (_) in
            let alert = UIAlertController(title: "", message: "Bloqueaste a \(self.userFullname!)", preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }))
        
        sheetController.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
        
        present(sheetController, animated: true, completion: nil)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if reviewViewModels.count > 0 {
            self.messageLabel.isHidden = true
        }
        return reviewViewModels.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: homeReviewCellId, for: indexPath) as! HomeReviewCell
        cell.reviewViewModel = reviewViewModels[indexPath.item]
        cell.backgroundColor = .white
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(showArrow))
        cell.arrowView.isUserInteractionEnabled = true
        cell.arrowView.addGestureRecognizer(tap)
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 20
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        let frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 50)
        let dummyCell = HomeReviewCell(frame: frame)
        dummyCell.reviewViewModel = reviewViewModels[indexPath.item]
        dummyCell.layoutIfNeeded()
        
        let targetSize = CGSize(width: view.frame.width, height: 1000)
        let estimatedSize = dummyCell.systemLayoutSizeFitting(targetSize)
        
        let height = max(40 + 8 + 8, estimatedSize.height)
        return CGSize(width: view.frame.width, height: height)
        
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "headerId", for: indexPath) as! UserProfileHeader
        header.backgroundColor = UIColor.white
        header.userViewModel = self.userViewModel
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(blockUser))
        header.arrowView.isUserInteractionEnabled = true
        header.arrowView.addGestureRecognizer(tap)
        
        return header
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        
        return CGSize(width: view.frame.width, height: 246/*248*/) //231 real height  ||  +12 for bottom space
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
	guard let input = input else { return nil }
	return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value)})
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromNSAttributedStringKey(_ input: NSAttributedString.Key) -> String {
	return input.rawValue
}
