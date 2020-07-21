
import Prelude

public protocol Reader {
    associatedtype Input
    associatedtype Output

    func run(_ input: Input) -> Output
}

public enum Readers {
}

// MARK: - FlatMap

public extension Readers {
    struct FlatMap<R: Reader, B: Reader> where R.Input == B.Input {
        fileprivate let transform: (R.Output) -> B
        fileprivate let upstream: R
    }
}
extension Readers.FlatMap: Reader {
    public typealias Input = R.Input
    public typealias Output = B.Output

    public func run(_ input: R.Input) -> B.Output {
        let next = transform <| upstream.run(input)
        return next.run(input)
    }
}
public extension Reader {
    func flatMap<B: Reader>(_ transform: @escaping (Output) -> B) -> Readers.FlatMap<Self, B> {
        .init(transform: transform, upstream: self)
    }
}

public extension Readers {
    struct Fold<A, B, R: Reader, E> where R.Output == Result<A, E> {
        fileprivate let transformValue: (A) -> B
        fileprivate let transformError: (E) -> B
        fileprivate let upstream: R
    }
}
extension Readers.Fold: Reader {
    public typealias Input = R.Input
    public typealias Output = B

    public func run(_ input: R.Input) -> B {
        switch upstream.run(input) {
        case .failure(let error):
            return transformError(error)
        case .success(let value):
            return transformValue(value)
        }
    }
}
public extension Reader {
    func fold<A, B, E>(
        transformValue: @escaping (A) -> B,
        transformError: @escaping (E) -> B) -> Readers.Fold<A, B, Self, E> {
        .init(transformValue: transformValue, transformError: transformError, upstream: self)
    }

    func replaceError<A, E>(_ replaceError: @autoclosure @escaping () -> A) -> Readers.Fold<A, A, Self, E> {
        .init(transformValue: id(_:), transformError: { _ in replaceError() }, upstream: self)
    }
}

// MARK: - Map

public extension Readers {
    struct Map<A: Reader, B> {
        fileprivate let transform: (A.Output) -> B
        fileprivate let upstream: A
    }
}
extension Readers.Map: Reader {
    public typealias Input = A.Input
    public typealias Output = B

    public func run(_ input: A.Input) -> B {
        return transform <| upstream.run(input)
    }
}
public extension Reader {
    func map<B>(_ transform: @escaping (Output) -> B) -> Readers.Map<Self, B> {
        .init(transform: transform, upstream: self)
    }
}

// MARK: - MapSuccess

public extension Readers {
    struct MapSuccess<A, B, R: Reader, E> where R.Output == Result<A, E> {
        fileprivate let transform: (A) -> B
        fileprivate let upstream: R
    }
}
extension Readers.MapSuccess: Reader {
    public typealias Input = R.Input
    public typealias Output = Result<B, E>

    public func run(_ input: R.Input) -> Result<B, E> {
        upstream.run(input).map(transform)
    }
}
public extension Reader {
    func mapSuccess<A, B, E>(
        _ transform: @escaping (A) -> B) -> Readers.MapSuccess<A, B, Self, E> where Output == Result<A, E> {
        .init(transform: transform, upstream: self)
    }
}

// MARK: - Pullback

public extension Readers {
    struct Pullback<R: Reader, J> {
        fileprivate let transform: (J) -> R.Input
        fileprivate let upstream: R
    }
}
extension Readers.Pullback: Reader {
    public typealias Input = J
    public typealias Output = R.Output

    public func run(_ input: J) -> R.Output {
        upstream.run(transform <| input)
    }
}
public extension Reader {
    func pullback<J>(to _: J.Type = J.self, _ transform: @escaping (J) -> Input) -> Readers.Pullback<Self, J> {
        .init(transform: transform, upstream: self)
    }
}

// MARK: - Tap

public extension Readers {
    struct Tap<R: Reader> {
        fileprivate let execute: (R.Output) -> Void
        fileprivate let upstream: R
    }
}
extension Readers.Tap: Reader {
    public typealias Input = R.Input
    public typealias Output = R.Output

    public func run(_ input: R.Input) -> R.Output {
        let value = upstream.run(input)
        execute(value)
        return value
    }
}
public extension Reader {
    func tap(_ execute: @escaping (Output) -> Void) -> Readers.Tap<Self> {
        .init(execute: execute, upstream: self)
    }
}

// MARK: - TryMap

public extension Readers {
    struct TryMap<R: Reader, B> {
        fileprivate let transform: (R.Output) throws -> B
        fileprivate let upstream: R
    }
}
extension Readers.TryMap: Reader {
    public typealias Input = R.Input
    public typealias Output = Result<B, Error>

    public func run(_ input: R.Input) -> Result<B, Error> {
        let value = upstream.run(input)
        return Result { try self.transform(value) }
    }
}
public extension Reader {
    func tryMap<B>(_ transform: @escaping (Output) throws -> B) -> Readers.TryMap<Self, B> {
        .init(transform: transform, upstream: self)
    }
}

// MARK: - TryMapSuccess

public extension Readers {
    struct TryMapSuccess<A, B, R: Reader> where R.Output == Result<A, Error> {
        fileprivate let transform: (A) throws -> B
        fileprivate let upstream: R
    }
}
extension Readers.TryMapSuccess: Reader {
    public typealias Input = R.Input
    public typealias Output = Result<B, Error>

    public func run(_ input: R.Input) -> Result<B, Error> {
        let result = upstream.run(input)
        return result.flatMap { value in Result { try self.transform(value) } }
    }
}
public extension Reader {
    func tryMapSuccess<A, B>(_ transform: @escaping (A) throws -> B) -> Readers.TryMapSuccess<A, B, Self> where Output == Result<A, Error> {
        .init(transform: transform, upstream: self)
    }
}

// MARK: - AnyReader

public struct AnyReader<I, O> {
    fileprivate let upstream: (I) -> O
}

public extension AnyReader {
    init(_ upstream: @escaping (I) -> O) {
        self.init(upstream: upstream)
    }
}

extension AnyReader: Reader {
    public typealias Input = I
    public typealias Output = O

    public func run(_ input: I) -> O {
        upstream(input)
    }
}
public extension Reader {
    func eraseToAnyReader() -> AnyReader<Input, Output> {
        .init(upstream: self.run)
    }
}
