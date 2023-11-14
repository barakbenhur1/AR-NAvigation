//
//  IAPManager.swift
//  http://apphud.com
//
//  Created by Apphud on 04/01/2019.
//  Copyright © 2019 Apphud. All rights reserved.
//

import UIKit
import StoreKit

public typealias SuccessBlock = ([String]) -> Void
public typealias FailureBlock = (Error?) -> Void

class SubscriptionService : NSObject {
    
    private var sharedSecret = ""
    
    @objc static let shared = SubscriptionService()
    var products: ((Array<SKProduct>) -> ())?
    
    private override init(){}
    private var productIds : Set<String> = []
    
    private var successBlock : SuccessBlock?
    private var failureBlock : FailureBlock?
    private var startBlock : (() -> ())?
    
    private var refreshSubscriptionSuccessBlock : SuccessBlock?
    private var refreshSubscriptionFailureBlock : FailureBlock?
    
    
    private var timer: Timer!
    private var removedAds = false
    
    private var  restorePurchases = false
    private var didEnd = false
    
    var removedAdsPurchesd: Bool {
        get {
            return removedAds
        }
    }
    
    // MARK:- Main methods
    
    @objc func startWith(arrayOfIds : Set<String>!, sharedSecret : String, products:  @escaping ((Array<SKProduct>) -> ())) {
        SKPaymentQueue.default().add(self)
        self.sharedSecret = sharedSecret
        self.productIds = arrayOfIds
        self.products = products
        loadProducts()
    }
    
    func expirationDateFor(_ identifier : String) -> Date?{
        return UserDefaults.standard.object(forKey: identifier) as? Date
    }
    
    func purchaseProduct(product : SKProduct, success: @escaping SuccessBlock, failure: @escaping FailureBlock, start: @escaping () -> ()){
        guard SKPaymentQueue.canMakePayments() else {
            return
        }
        guard SKPaymentQueue.default().transactions.last?.transactionState != .purchasing else {
            return
        }
        self.successBlock = success
        self.failureBlock = failure
        self.startBlock = start
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases(success: @escaping SuccessBlock, failure: @escaping FailureBlock) {
        self.successBlock = success
        self.failureBlock = failure
        SKPaymentQueue.default().add(self)
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    /* It's the most simple way to send verify receipt request. Consider this code as for learning purposes. You shouldn't use current code in production apps.
     This code doesn't handle errors.
     */
    func refreshSubscriptionsStatus(callback : @escaping SuccessBlock, failure : @escaping FailureBlock){
        
        self.refreshSubscriptionSuccessBlock = callback
        self.refreshSubscriptionFailureBlock = failure
        
        guard let receiptUrl = Bundle.main.appStoreReceiptURL else {
            refreshReceipt()
            // do not call block in this case. It will be called inside after receipt refreshing finishes.
            return
        }
        
        #if DEBUG
        let urlString = "https://sandbox.itunes.apple.com/verifyReceipt"
        #else
        let urlString = "https://buy.itunes.apple.com/verifyReceipt"
        #endif
        let receiptData = try? Data(contentsOf: receiptUrl).base64EncodedString()
        let requestData = ["receipt-data" : receiptData ?? "", "password" : self.sharedSecret, "exclude-old-transactions" : true] as [String : Any]
        var request = URLRequest(url: URL(string: urlString)!)
        request.httpMethod = "POST"
        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
        let httpBody = try? JSONSerialization.data(withJSONObject: requestData, options: [])
        request.httpBody = httpBody
        
        URLSession.shared.dataTask(with: request)  { (data, response, error) in
            DispatchQueue.main.async {
                if data != nil {
                    if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments){
                        self.parseReceipt(json as! Dictionary<String, Any>)
                        return
                    }
                } else {
                    print("error validating receipt: \(error?.localizedDescription ?? "")")
                }
                self.refreshSubscriptionFailureBlock?(error)
                self.cleanUpRefeshReceiptBlocks()
            }
            }.resume()
    }
    
    /* It's the most simple way to get latest expiration date. Consider this code as for learning purposes. You shouldn't use current code in production apps.
     This code doesn't handle errors or some situations like cancellation date.
     */
    private func parseReceipt(_ json : Dictionary<String, Any>) {
        guard let receipts_array = json["latest_receipt_info"] as? [Dictionary<String, Any>] else {
            self.refreshSubscriptionSuccessBlock?([])
            self.cleanUpRefeshReceiptBlocks()
            return
        }
        
        var productIDs = [String]()
        for receipt in receipts_array {
            let productID = receipt["product_id"] as! String
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
            if let date = formatter.date(from: receipt["expires_date"] as! String) {
                if date > Date() {
                    productIDs.append(productID)
                }
            }
        }
        
        if productIDs.isEmpty {
            self.refreshSubscriptionFailureBlock?(nil)
        }
        else {
            self.refreshSubscriptionSuccessBlock?(productIDs)
        }
        self.cleanUpRefeshReceiptBlocks()
    }
    
    /*
     Private method. Should not be called directly. Call refreshSubscriptionsStatus instead.
     */
    private func refreshReceipt(){
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = self
        request.start()
    }
    
    private func loadProducts(){
        let request = SKProductsRequest(productIdentifiers: productIds)
        request.delegate = self
        request.start()
    }
    
    private func cleanUpRefeshReceiptBlocks(){
        self.refreshSubscriptionSuccessBlock = nil
        self.refreshSubscriptionFailureBlock = nil
    }
    
    @discardableResult func handelePremium() async -> Bool {
        return await withCheckedContinuation({ c in
            restorePurchases = false
            didEnd = false
            
            DispatchQueue.main.async {
                self.timer = Timer(timeInterval: 10, repeats: false, block: { timer in
                    guard !self.restorePurchases else { return }
                    self.didEnd = true
                    self.restorePurchases = true
                    self.removedAds = false

                    
                    c.resume(returning: false)
                })
                
                RunLoop.current.add(self.timer, forMode: .common)
            }
            
            restorePurchases { ids in
                guard !self.didEnd else { return }
                self.timer.invalidate()
                self.restorePurchases = true
                self.removedAds = ids.contains(where: { s in s.contains("argo.removeAds") })
                c.resume(returning: true)
            } failure: { error in
                guard !self.didEnd else { return }
                self.timer.invalidate()
                self.restorePurchases = true
                self.removedAds = false
                c.resume(returning: false)
            }
        })
    }
}

// MARK:- SKReceipt Refresh Request Delegate

extension SubscriptionService : SKRequestDelegate {
    
    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            refreshSubscriptionsStatus(callback: self.successBlock ?? {_ in}, failure: self.failureBlock ?? {_ in})
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error){
        if request is SKReceiptRefreshRequest {
            self.refreshSubscriptionFailureBlock?(error)
            self.cleanUpRefeshReceiptBlocks()
        }
        print("error: \(error.localizedDescription)")
    }
}

// MARK:- SKProducts Request Delegate

extension SubscriptionService: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        products?(response.products)
    }
}

// MARK:- SKPayment Transaction Observer

extension SubscriptionService: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        if transactions.isEmpty {
            return
        }
        
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .purchased:
                SKPaymentQueue.default().finishTransaction(transaction)
                notifyIsPurchased(transaction: transaction)
                break
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
                print("purchase error : \(transaction.error?.localizedDescription ?? "")")
                self.failureBlock?(transaction.error)
                cleanUp()
                break
            case .restored:
                SKPaymentQueue.default().finishTransaction(transaction)
                break
            case .deferred, .purchasing:
                break
            default:
                break
            }
        }
    }
    
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        self.failureBlock?(error)
        self.cleanUp()
    }
    
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        let ids = queue.transactions.map { $0.payment.productIdentifier }
        self.successBlock?(ids)
        self.cleanUp()
    }
    
    private func notifyIsPurchased(transaction: SKPaymentTransaction) {
        refreshSubscriptionsStatus(callback: { ids in
            let ids = ids.isEmpty ? [transaction.payment.productIdentifier] : ids
            self.successBlock?(ids)
            self.cleanUp()
        }) { (error) in
            // couldn't verify receipt
            self.failureBlock?(error)
            self.cleanUp()
        }
    }
    
    func cleanUp(){
        self.startBlock?()
        self.startBlock = nil
        self.successBlock = nil
        self.failureBlock = nil
    }
}
