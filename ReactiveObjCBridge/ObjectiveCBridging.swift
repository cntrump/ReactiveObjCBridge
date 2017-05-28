//
//  ObjectiveCBridging.swift
//  ReactiveObjCBridge
//
//  Created by Justin Spahr-Summers on 2014-07-02.
//  Copyright (c) 2014 GitHub, Inc. All rights reserved.
//

import Foundation
import ReactiveObjC
import ReactiveSwift
import Result

extension SignalProtocol {
	/// Turns each value into an Optional.
	fileprivate func optionalize() -> Signal<Value?, Error> {
		return map(Optional.init)
	}
}

extension SignalProducerProtocol {
	/// Turns each value into an Optional.
	fileprivate func optionalize() -> SignalProducer<Value?, Error> {
		return lift { $0.optionalize() }
	}
}

extension RACDisposable: Disposable {
	public convenience init(_ disposable: Disposable?) {
		if let disposable = disposable {
			self.init(block: disposable.dispose)
		} else {
			self.init()
		}
	}
}

extension RACScheduler: DateScheduler {
	/// The current date, as determined by this scheduler.
	public var currentDate: Date {
		return Date()
	}

	/// Schedule an action for immediate execution.
	///
	/// - note: This method calls the Objective-C implementation of `schedule:`
	///         method.
	///
	/// - parameters:
	///   - action: Closure to perform.
	///
	/// - returns: Disposable that can be used to cancel the work before it
	///            begins.
	@discardableResult
	public func schedule(_ action: @escaping () -> Void) -> Disposable? {
		let disposable: RACDisposable? = self.schedule(action) // Call the Objective-C implementation
		return disposable as Disposable?
	}

	/// Schedule an action for execution at or after the given date.
	///
	/// - parameters:
	///   - date: Starting date.
	///   - action: Closure to perform.
	///
	/// - returns: Optional disposable that can be used to cancel the work
	///            before it begins.
	@discardableResult
	public func schedule(after date: Date, action: @escaping () -> Void) -> Disposable? {
		return self.after(date, schedule: action)
	}

	/// Schedule a recurring action at the given interval, beginning at the
	/// given start time.
	///
	/// - parameters:
	///   - date: Starting date.
	///   - repeatingEvery: Repetition interval.
	///   - withLeeway: Some delta for repetition.
	///   - action: Closure of the action to perform.
	///
	/// - returns: Optional `Disposable` that can be used to cancel the work
	///            before it begins.
	@discardableResult
	public func schedule(after date: Date, interval: DispatchTimeInterval, leeway: DispatchTimeInterval, action: @escaping () -> Void) -> Disposable? {
		return self.after(date, repeatingEvery: interval.timeInterval, withLeeway: leeway.timeInterval, schedule: action)
	}
}

extension ImmediateScheduler {
	/// Create `RACScheduler` that performs actions instantly.
	///
	/// - returns: `RACScheduler` that instantly performs actions.
	@available(*, deprecated, message:"Use `RACScheduler.immediate` directly, or `RACScheduler.init` in a generic context.")
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler.immediate()
	}
}

extension UIScheduler {
	/// Create `RACScheduler` for `UIScheduler`
	///
	/// - returns: `RACScheduler` instance that queues events on main thread.
	@available(*, deprecated, message:"Use `RACScheduler.init` to wrap an `UIScheduler` instead.")
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler(self)
	}
}

extension QueueScheduler {
	/// Create `RACScheduler` backed with own queue
	///
	/// - returns: Instance `RACScheduler` that queues events on
	///            `QueueScheduler`'s queue.
	@available(*, deprecated, message:"Use `RACScheduler.init` to wrap a `QueueScheduler` instead.")
	public func toRACScheduler() -> RACScheduler {
		return RACScheduler(self)
	}
}

extension RACScheduler {
	/// Create a `RACScheduler` that wraps the given scheduler.
	///
	/// - parameters:
	///   - scheduler: The `Scheduler` to wrap.
	///
	/// - returns: A `RACScheduler` that schedules blocks to `scheduler`.
	public convenience init(_ scheduler: Scheduler) {
		self.init(racSwiftScheduler: RACSwiftScheduler(wrapping: scheduler))
	}

	/// Create a `RACScheduler` that wraps the given scheduler.
	///
	/// - parameters:
	///   - scheduler: The `DateScheduler` to wrap.
	///
	/// - returns: A `RACScheduler` that schedules blocks to `scheduler`.
	public convenience init(_ scheduler: DateScheduler) {
		self.init(racSwiftScheduler: RACSwiftScheduler(wrapping: scheduler))
	}
}

private final class RACSwiftScheduler: RACScheduler {
	enum Backing {
		case scheduler(Scheduler)
		case dateScheduler(DateScheduler)
	}

	private let base: Backing

	init(wrapping base: Scheduler) {
		self.base = .scheduler(base)
	}

	init(wrapping base: DateScheduler) {
		self.base = .dateScheduler(base)
	}

	private func wrap(_ block: @escaping () -> Void) -> () -> Void {
		return {
			Thread.current.threadDictionary["RACSchedulerCurrentSchedulerKey"] = self
			block()
			Thread.current.threadDictionary["RACSchedulerCurrentSchedulerKey"] = nil
		}
	}

	open override func schedule(_ block: @escaping () -> Void) -> RACDisposable? {
		switch base {
		case let .scheduler(scheduler):
			return scheduler.schedule(wrap(block)).map(RACDisposable.init)

		case let .dateScheduler(scheduler):
			return scheduler.schedule(wrap(block)).map(RACDisposable.init)
		}
	}

	open override func after(_ date: Date, schedule block: @escaping () -> Swift.Void) -> RACDisposable? {
		switch base {
		case let .scheduler(scheduler):
			Thread.sleep(until: date)
			return scheduler.schedule(wrap(block)).map(RACDisposable.init)

		case let .dateScheduler(scheduler):
			return scheduler.schedule(after: date,
			                          action: wrap(block)).map(RACDisposable.init)
		}
	}

	open override func after(_ date: Date, repeatingEvery interval: TimeInterval, withLeeway leeway: TimeInterval, schedule block: @escaping () -> Void) -> RACDisposable? {
		switch base {
		case let .scheduler(scheduler):
			assertionFailure("Undefined behavior.")
			return scheduler.schedule(wrap(block)).map(RACDisposable.init)

		case let .dateScheduler(scheduler):
			return scheduler.schedule(after: date,
			                          interval: .milliseconds(Int(interval * 1000)),
			                          leeway: .milliseconds(Int(leeway * 1000)),
			                          action: wrap(block))
				.map(RACDisposable.init)
		}
	}
}

private func defaultNSError(_ message: String) -> NSError {
	return Result<(), NSError>.error(message)
}

private func defaultNSError(_ message: String, file: String, line: Int) -> NSError {
	return Result<(), NSError>.error(message, file: file, line: line)
}

@available(*, unavailable, renamed:"SignalProducer(_:)")
public func bridgedSignalProducer<Value>(from signal: RACSignal<Value>) -> SignalProducer<Value?, AnyError> {
	fatalError()
}

extension SignalProducer where Error == AnyError {
	/// Create a `SignalProducer` which will subscribe to the provided signal once
	/// for each invocation of `start()`.
	///
	/// - parameters:
	///   - signal: The signal to bridge to a signal producer.
	public init<SignalValue>(_ signal: RACSignal<SignalValue>) where Value == SignalValue? {
		self.init { observer, disposable in
			let failed: (_ error: Swift.Error?) -> () = { error in
				observer.send(error: AnyError(error ?? defaultNSError("Nil RACSignal error")))
			}

			disposable += signal.subscribeNext(observer.send(value:),
			                                   error: failed,
			                                   completed: observer.sendCompleted)
		}
	}
}

extension SignalProducerProtocol where Value: AnyObject {
	/// A bridged `RACSignal` that will `start()` the producer once for each subscription.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	public var bridged: RACSignal<Value> {
		return RACSignal<Value>.createSignal { subscriber in
			let selfDisposable = self.start { event in
				switch event {
				case let .value(value):
					subscriber.sendNext(value)
				case let .failed(error):
					subscriber.sendError(error)
				case .completed:
					subscriber.sendCompleted()
				case .interrupted:
					break
				}
			}

			return RACDisposable(selfDisposable)
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACSignal() -> RACSignal<Value> { return bridged }
}

extension SignalProducerProtocol where Value: OptionalProtocol, Value.Wrapped: AnyObject {
	/// A bridged `RACSignal` that will `start()` the producer once for each subscription.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - note: This overload is necessary to prevent `Optional.none` from
	///         being bridged to `NSNull` (instead of `nil`).
	///         See ReactiveObjCBridge#5 for more details.
	public var bridged: RACSignal<Value.Wrapped> {
		return RACSignal<Value.Wrapped>.createSignal { subscriber in
			let selfDisposable = self.start { event in
				switch event {
				case let .value(value):
					subscriber.sendNext(value.optional)
				case let .failed(error):
					subscriber.sendError(error)
				case .completed:
					subscriber.sendCompleted()
				case .interrupted:
					break
				}
			}
			
			return RACDisposable(selfDisposable)
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACSignal() -> RACSignal<Value.Wrapped> { return bridged }
}

extension SignalProtocol where Value: AnyObject {
	/// A bridged `RACSignal` that will observe the given signal.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	public var bridged: RACSignal<Value> {
		return RACSignal<Value>.createSignal { subscriber in
			let selfDisposable = self.observe { event in
				switch event {
				case let .value(value):
					subscriber.sendNext(value)
				case let .failed(error):
					subscriber.sendError(error)
				case .completed:
					subscriber.sendCompleted()
				case .interrupted:
					break
				}
			}

			return RACDisposable(selfDisposable)
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACSignal() -> RACSignal<Value> { return bridged }
}

extension SignalProtocol where Value: OptionalProtocol, Value.Wrapped: AnyObject {
	/// A bridged `RACSignal` that will observe the given signal.
	///
	/// - note: Any `interrupted` events will be silently discarded.
	///
	/// - note: This overload is necessary to prevent `Optional.none` from 
	///         being bridged to `NSNull` (instead of `nil`).
	///         See ReactiveObjCBridge#5 for more details.
	public var bridged: RACSignal<Value.Wrapped> {
		return RACSignal<Value.Wrapped>.createSignal { subscriber in
			let selfDisposable = self.observe { event in
				switch event {
				case let .value(value):
					subscriber.sendNext(value.optional)
				case let .failed(error):
					subscriber.sendError(error)
				case .completed:
					subscriber.sendCompleted()
				case .interrupted:
					break
				}
			}
			
			return RACDisposable(selfDisposable)
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACSignal() -> RACSignal<Value.Wrapped> { return bridged }
}

extension Action {
	fileprivate var isCommandEnabled: RACSignal<NSNumber> {
		return self.isEnabled.producer.map { $0 as NSNumber }.bridged
	}
}

@available(*, unavailable, renamed:"Action(_:)")
public func bridgedAction<Input, Output>(from command: RACCommand<Input, Output>) -> Action<Input?, Output?, AnyError> {
	fatalError()
}

extension Action where Error == AnyError {
	/// Create an Action that wraps the given command.
	///
	/// - note: The created `Action` will not necessarily be marked as executing
	///         when the command is. However, the reverse is always true: the
	///         `RACCommand` will always be marked as executing when the action
	///         is.
	///
	/// - parameters:
	///   - command: The command to wrap.
	public convenience init<CommandInput, CommandOutput>(
		_ command: RACCommand<CommandInput, CommandOutput>
	) where Input == CommandInput?, Output == CommandOutput? {
		let enabledProperty = MutableProperty(true)

		enabledProperty <~ SignalProducer(command.enabled)
			.map { $0 as! Bool }
			.flatMapError { _ in SignalProducer<Bool, NoError>(value: false) }

		self.init(enabledIf: enabledProperty) { input -> SignalProducer<Output, AnyError> in
			let signal: RACSignal<CommandOutput> = command.execute(input)

			return SignalProducer(signal)
		}
	}
}

extension Action where Input: AnyObject, Output: AnyObject {
	/// A bridged `RACCommand` that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the `RACCommand` is.
	public var bridged: RACCommand<Input, Output> {
		return RACCommand<Input, Output>(enabled: action.isCommandEnabled) { input -> RACSignal<Output> in
			return self.apply(input!).bridged
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACCommand() -> RACCommand<Input, Output> { return bridged }
}

extension Action where Input: OptionalProtocol, Input.Wrapped: AnyObject, Output: AnyObject {
	/// A bridged `RACCommand` that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the `RACCommand` is.
	public var bridged: RACCommand<Input.Wrapped, Output> {
		return RACCommand<Input.Wrapped, Output>(enabled: action.isCommandEnabled) { input -> RACSignal<Output> in
			return self.apply(Input(reconstructing: input)).bridged
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACCommand() -> RACCommand<Input.Wrapped, Output> { return bridged }
}

extension Action where Input: AnyObject, Output: OptionalProtocol, Output.Wrapped: AnyObject {
	/// A bridged `RACCommand` that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the `RACCommand` is.
	public var bridged: RACCommand<Input, Output.Wrapped> {
		return RACCommand<Input, Output.Wrapped>(enabled: action.isCommandEnabled) { input -> RACSignal<Output.Wrapped> in
			return self.apply(input!).bridged
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACCommand() -> RACCommand<Input, Output.Wrapped> { return bridged }
}

extension Action where Input: OptionalProtocol, Input.Wrapped: AnyObject, Output: OptionalProtocol, Output.Wrapped: AnyObject {
	/// A bridged `RACCommand` that will execute the action.
	///
	/// - note: The returned command will not necessarily be marked as executing
	///         when the action is. However, the reverse is always true: the Action
	///         will always be marked as executing when the RACCommand is.
	public var bridged: RACCommand<Input.Wrapped, Output.Wrapped> {
		return RACCommand<Input.Wrapped, Output.Wrapped>(enabled: action.isCommandEnabled) { input -> RACSignal<Output.Wrapped> in
			return self.apply(Input(reconstructing: input)).bridged
		}
	}

	@available(*, deprecated, message:"Use the `bridged` property instead.")
	public func toRACCommand() -> RACCommand<Input.Wrapped, Output.Wrapped> { return bridged }
}

// MARK: - Helpers

extension DispatchTimeInterval {
	fileprivate var timeInterval: TimeInterval {
		switch self {
		case let .seconds(s):
			return TimeInterval(s)
		case let .milliseconds(ms):
			return TimeInterval(TimeInterval(ms) / 1000.0)
		case let .microseconds(us):
			return TimeInterval(UInt64(us) * NSEC_PER_USEC) / TimeInterval(NSEC_PER_SEC)
		case let .nanoseconds(ns):
			return TimeInterval(ns) / TimeInterval(NSEC_PER_SEC)
		}
	}
}
