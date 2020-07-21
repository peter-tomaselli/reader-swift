
import Reader

struct Person {
    var firstName, lastName: String
}

let myReader = AnyReader<Person, String> { person in "\(person.firstName) \(person.lastName)" }

let person = Person(firstName: "foo", lastName: "bar")

myReader.run(person)

let x = myReader
    .tap { print("1. processing the person: \($0)") }
    .map { "\($0)!" }
    .eraseToAnyReader()

x.run(person)

struct MyError: Error { }

let y = myReader
    .tap { print("2. processing the person: \($0)") }
    .tryMap { string throws -> Int in
        if string.count == 5 {
            throw MyError()
        }
        return string.count
}
    .mapSuccess { count in "the count was: \(count)" }
    .eraseToAnyReader()

y.run(person)

y.run(.init(firstName: "ab", lastName: "cd"))

extension Readers {
    struct TryPullback<R: Reader, J> {
        fileprivate let transform: (J) throws -> R.Input
        fileprivate let upstream: R
    }
}
extension Readers.TryPullback: Reader {
    typealias Input = J
    typealias Output = Result<R.Output, Error>

    func run(_ input: J) -> Result<R.Output, Error> {
        let nextInput = Result { try transform(input) }
        return nextInput.map { upstream.run($0) }
    }
}
extension Reader {
    func tryPullback<J>(to _: J.Type = J.self, _ transform: @escaping (J) throws -> Input) -> Readers.TryPullback<Self, J> {
        .init(transform: transform, upstream: self)
    }
}

let z = myReader
    .tryPullback(to: [Person].self) { array in
        guard let firstPerson = array.first else {
            throw MyError()
        }
        return firstPerson
}

let people = [Person(firstName: "foo", lastName: "bar"), Person(firstName: "baz", lastName: "qux")]

z.run(people)

z.run([])
