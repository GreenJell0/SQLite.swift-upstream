//
// SQLite.swift
// https://github.com/stephencelis/SQLite.swift
// Copyright © 2014-2015 Stephen Celis.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

public protocol ExpressionType: Expressible { // extensions cannot have inheritance clauses

    associatedtype UnderlyingType = Void

    var template: String { get }
    var bindings: [Binding?] { get }
    var alias: String? { get }

    init(_ template: String, _ bindings: [Binding?], _ alias: String?)

}

extension ExpressionType {

    public init(literal: String, alias: String? = nil) {
        self.init(literal, [], alias)
    }


    public init(_ identifier: String) {
        self.init(literal: identifier.quote())
    }

    public init<U: ExpressionType>(_ expression: U) {
        self.init(expression.template, expression.bindings, expression.alias)
    }

}

/// An `Expression` represents a raw SQL fragment and any associated bindings.
public struct Expression<Datatype>: ExpressionType {

    public typealias UnderlyingType = Datatype

    public var template: String
    public var bindings: [Binding?]
    public var alias: String?

    public init(_ template: String, _ bindings: [Binding?], _ alias: String? = nil) {
        self.template = template
        self.bindings = bindings
        self.alias = alias
    }

}

public protocol Expressible {

    var expression: Expression<Void> { get }

}

extension Expressible {

    // naïve compiler for statements that can’t be bound, e.g., CREATE TABLE
    // FIXME: make internal (0.13.0)
    public func asSQL() -> String {
        let expressed = expression
        var idx = 0
        return expressed.template.reduce("") { template, character in
            let transcoded: String

            if character == "?" {
                transcoded = transcode(expressed.bindings[idx])
                idx += 1
            } else {
                transcoded = String(character)
            }
            return template + transcoded
        }
    }

}

extension ExpressionType {

    public var expression: Expression<Void> {
        Expression(template, bindings, alias)
    }

    public var asc: Expressible {
        " ".join([self, Expression<Void>(literal: "ASC")])
    }

    public var desc: Expressible {
        " ".join([self, Expression<Void>(literal: "DESC")])
    }

}

extension ExpressionType where UnderlyingType: Value {

    public init(value: UnderlyingType) {
        self.init("?", [value.datatypeValue], nil)
    }

}

extension ExpressionType where UnderlyingType: _OptionalType, UnderlyingType.WrappedType: Value {

    public static var null: Self {
        self.init(value: nil)
    }

    public init(value: UnderlyingType.WrappedType?) {
        self.init("?", [value?.datatypeValue], nil)
    }

}

extension Value {

    public var expression: Expression<Void> {
        Expression(value: self).expression
    }

}

public let rowid = Expression<Int64>("ROWID")

public func cast<T: Value, U: Value>(_ expression: Expression<T>) -> Expression<U> {
    Expression("CAST (\(expression.template) AS \(U.declaredDatatype))", expression.bindings, expression.alias)
}

public func cast<T: Value, U: Value>(_ expression: Expression<T?>) -> Expression<U?> {
    Expression("CAST (\(expression.template) AS \(U.declaredDatatype))", expression.bindings, expression.alias)
}
