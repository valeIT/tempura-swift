//
//  ViewControllerWithLocalState.swift
//  Tempura
//
//  Created by Andrea De Angelis on 31/07/2017.
//
//

import Foundation
import UIKit
import Katana


// --------- SWIFT 3.2 IMPLEMENTATION ----------
// --------- due to a bug in Swift 3.1 we can't inherit from ViewController --------------
// this implementation is valid starting from Swift 3.2, in the meantime we are copying the ViewController implementation instead of extending the class

/*open class ViewControllerWithLocalState<V: ViewControllerModellableView, S: State>: ViewController<V, S> where V.VM.S == S, V.VM.LS == LS, V.VM: ViewModelWithLocalState {
  public var localState: LS = LS() {
    didSet {
      self.localStateDidChange()
    }
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    self.localStateDidChange()
  }
 
  open func update(with state: S) {
      // update the view model using the new state available
     self.viewModel = LVM(state: state, localState: self.localState)
 }
  
  private func localStateDidChange() {
    self.updateLocalState(with: self.localState)
  }
  
  open func updateLocalState(with localState: LS) {
    guard let state = self.store.anyState as? S else { fatalError("wrong state type") }
    self.viewModel = LVM(state: state, localState: localState)
  }
}*/


// ----------- Swift 3.1 implementation, remove as soon as 3.2 is available in production
open class ViewControllerWithLocalState<V: ViewControllerModellableView, S: State, LS: LocalState>: UIViewController where V.VM.S == S, V.VM.LS == LS, V.VM: ViewModelWithLocalState {
  
  /// true if the viewController is connected to the store, false otherwise
  /// a connected viewController will receive all the updates from the store
  open var connected: Bool = true {
    didSet {
      guard self.connected != oldValue else { return }
      
      if self.connected {
        self.subscribeToStateUpdates()
      } else {
        self.unsubscribe?()
        self.unsubscribe = nil
      }
    }
  }
  
  /// the store the viewController will use to receive state updates
  public var store: AnyStore
  
  /// closure used to unsubscribe the viewController from state updates
  private var unsubscribe: StoreUnsubscribe?
  
  /// used to have the last viewModel available if we want to update it for local state changes
  public var viewModel: V.VM = V.VM() {
    didSet {
      // the viewModel is changed, update the View
      self.rootView.model = viewModel
    }
  }
  
  /// the local state of this ViewController
  public var localState: LS = LS() {
    didSet {
      self.localStateDidChange()
    }
  }
  
  /// use the rootView to access the main view managed by this viewController
  open var rootView: V {
    return self.view as! V
  }
  
  /// used internally to load the specific main view managed by this view controller
  open override func loadView() {
    // TODO: this shitty force cast dance can be removed in swift 4
    let viewType = V.self as! UIView.Type
    let v = viewType.init(frame: .zero) as! V
    v.viewController = self
    v.setup()
    v.style()
    self.view = v as! UIView
  }
  
  /// the init of the view controller that will take the Store to perform the updates when the store changes
  public init(store: AnyStore, connected: Bool = true) {
    self.store = store
    self.connected = true
    super.init(nibName: nil, bundle: nil)
    self.setup()
  }
  
  // override to setup something after init
  open func setup() {}
  
  /// shortcut to the dispatch function
  open func dispatch(action: Action) {
    self.store.dispatch(action)
  }
  
  // we are not using storyboards so trigger a fatalError
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  /// subscribe to the state updates, the method storeDidChange will be called on every state change
  private func subscribeToStateUpdates() {
    // check if we are already subscribed
    guard self.unsubscribe == nil else { return }
    
    // subscribe
    let unsubscribe = self.store.addListener { [unowned self] in
      self.storeDidChange()
    }
    
    // trigger a state update
    self.storeDidChange()
    // save the unsubscribe closure
    self.unsubscribe = unsubscribe
  }
  
  /// this method is called every time the store trigger a state update
  /// ATTENTION: this method should be private, it's public just because there is a bug in swift 3.1
  /// preventing you to override the update(with state: S) method because it's generic
  /// this allow us to use `storeDidChange()` (that is not generic) as an overriding point
  /// TODO: make it private once we migrate to swift 4.0
  open func storeDidChange() {
    guard let newState = self.store.anyState as? S else { fatalError("wrong state type") }
    self.update(with: newState)
  }
  
  /// handle the state update, create a new updated viewModel and feed the view with that
  open func update(with state: S) {
    // update the view model using the new state available
    // note that the updated method should take into account the local state that should remain untouched
    self.viewModel = V.VM(state: state, localState: self.localState)
  }
  
  /// this method is called every time the local state changes
  /// ATTENTION: this method should be private, it's open just because there is a bug in swift 3.1
  /// preventing you to override the updateLocalState(with localState: LS) method because it's generic
  /// this allow us to use `localStateDidChange()` (that is not generic) as an overriding point
  /// TODO: make it private once we migrate to swift 4.0
  open func localStateDidChange() {
    self.updateLocalState(with: self.localState)
  }
  
  // handle the local state update
  open func updateLocalState(with localState: LS) {
    guard let state = self.store.anyState as? S else { fatalError("wrong state type") }
    self.viewModel = V.VM(state: state, localState: localState)
  }
  
  /// before the view will appear on screen, update the view and subscribe for state updates
  open override func viewWillAppear(_ animated: Bool) {
    if self.connected {
      self.subscribeToStateUpdates()
    }
    super.viewWillAppear(animated)
  }
  
  /// after the view disapper from screen, we stop listening for state updates
  open override func viewWillDisappear(_ animated: Bool) {
    if self.connected {
      self.unsubscribe?()
      self.unsubscribe = nil
    }
    super.viewWillDisappear(animated)
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    self.setupInteraction()
    self.localStateDidChange()
  }
  
  /// ask to setup the interaction with the managed view
  open func setupInteraction() {}
  
  // not necessary?
  deinit {
    self.unsubscribe?()
  }
}
