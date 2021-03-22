//
//  ViewModel.swift
//  QBChat-MVVM
//
//  Created by Paul Kraft on 30.10.19.
//  Copyright © 2019 QuickBird Studios. All rights reserved.
//

import Combine
import Foundation

protocol ViewModel: ObservableObject where ObjectWillChangePublisher.Output == Void {
    associatedtype State
    associatedtype Input

    var state: State { get }
    func trigger(_ input: Input)
    func forceUpdate(_ newState: State)
}

extension AnyViewModel: Identifiable where State: Identifiable {
    var id: State.ID {
        state.id
    }
}

@dynamicMemberLookup
final class AnyViewModel<State, Input>: ViewModel {

    // MARK: Stored properties

    private let wrappedObjectWillChange: () -> AnyPublisher<Void, Never>
    private let wrappedState: () -> State
    private let updateWrappedState: (State) -> Void
    private let wrappedTrigger: (Input) -> Void

    // MARK: Computed properties

    var objectWillChange: AnyPublisher<Void, Never> {
        wrappedObjectWillChange()
    }

    private(set) var state: State {
        get { wrappedState() }
        set { updateWrappedState(newValue) }
    }

    // MARK: Methods

    func trigger(_ input: Input) {
        wrappedTrigger(input)
    }
    
    func forceUpdate(_ newState: State) {
        assertionFailure("Should be implemented in concrete class instead of type erased version")
    }

    subscript<Value>(dynamicMember keyPath: KeyPath<State, Value>) -> Value {
        state[keyPath: keyPath]
    }

    // MARK: Initialization

    init<V: ViewModel>(_ viewModel: V) where V.State == State, V.Input == Input {
        self.wrappedObjectWillChange = { viewModel.objectWillChange.eraseToAnyPublisher() }
        self.wrappedState = { viewModel.state }
        self.wrappedTrigger = viewModel.trigger
        self.updateWrappedState = { viewModel.forceUpdate($0) }
    }

}

// MARK: - Binding implementations
import SwiftUI
extension AnyViewModel {
    /// Usage example: TextField(vm.textFieldText, text: vm.bind(on: \.text))
    func bind<Value>(on keyPath: WritableKeyPath<State, Value>) -> Binding<Value> {
        Binding(get: { self.state[keyPath: keyPath] },
                set: { self.state[keyPath: keyPath] = $0 })
    }
    
    /// Usage example: TextField(vm.textFieldText, text: vm.bind(\.text, to: { .bindTextInput(text: $0) }))
    func bind<Value>(_ keyPath: KeyPath<State, Value>,
                     to input: @escaping (Value) -> Input?) -> Binding<Value> {
        Binding(get: { self.state[keyPath: keyPath] },
                set: { input($0).map { self.trigger($0) } })
    }
    
    /// Usage example: TextField(vm.textFieldText, text: vm.bind({ $0.text }, to: { .bindTextInput(text: $0) }))
    func bind<Value>(_ value: @escaping (State) -> Value,
                     to input: @escaping (Value) -> Input?) -> Binding<Value> {
        Binding(get: { value(self.state) },
                set: { input($0).map { self.trigger($0) } })
    }
}
