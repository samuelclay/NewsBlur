import JavaScriptCore
import XCTest

final class StoryDetailHighlightTests: XCTestCase {
    func test_applyClassifierHighlights_appends_score_icons_for_async_marks() throws {
        let context = try makeContext()
        let scriptURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("static/storyDetailView.js")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        context.evaluateScript(script)
        XCTAssertNil(context.exception)

        let iconCount = context.evaluateScript(
            """
            resetMocks();
            applyClassifierHighlights({
                texts: { "Claude Code": 1 },
                text_regex: {}
            });
            flushTimeouts();
            flushPendingMarks();
            iconCount();
            """
        )

        XCTAssertNil(context.exception)
        XCTAssertEqual(iconCount?.toInt32(), 1)
    }

    func test_applyClassifierHighlights_does_not_stack_icons_on_rerun() throws {
        let context = try makeContext()
        let scriptURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("static/storyDetailView.js")
        let script = try String(contentsOf: scriptURL, encoding: .utf8)

        context.evaluateScript(script)
        XCTAssertNil(context.exception)

        let iconCount = context.evaluateScript(
            """
            resetMocks();
            applyClassifierHighlights({
                texts: { "Claude Code": 1 },
                text_regex: {}
            });
            flushTimeouts();
            flushPendingMarks();
            applyClassifierHighlights({
                texts: { "Claude Code": 1 },
                text_regex: {}
            });
            flushTimeouts();
            flushPendingMarks();
            totalIconCount();
            """
        )

        XCTAssertNil(context.exception)
        XCTAssertEqual(iconCount?.toInt32(), 1)
    }

    private func makeContext() throws -> JSContext {
        let context = try XCTUnwrap(JSContext())
        let exceptionExpectation = XCTestExpectation(description: "JavaScript exception")
        exceptionExpectation.isInverted = true

        context.exceptionHandler = { _, exception in
            if let exception {
                XCTFail("JavaScript exception: \(exception)")
                exceptionExpectation.fulfill()
            }
        }

        context.evaluateScript(
            #"""
            var timeoutQueue = [];
            var pendingMarks = [];

            function setTimeout(fn) {
                timeoutQueue.push(fn);
                return timeoutQueue.length;
            }

            function flushTimeouts() {
                while (timeoutQueue.length) {
                    timeoutQueue.shift()();
                }
            }

            function flushPendingMarks() {
                while (pendingMarks.length) {
                    pendingMarks.shift()();
                }
            }

            function MockElement(className, owner) {
                this.className = className || "";
                this.html = "";
                this.owner = owner || null;
                var self = this;
                this.classList = {
                    contains: function(name) {
                        return self.className.split(/\s+/).indexOf(name) !== -1;
                    }
                };
            }

            MockElement.prototype.querySelector = function(selector) {
                if (selector.indexOf("NB-score-icon") !== -1 && this.html.indexOf("NB-score-icon") !== -1) {
                    return {};
                }
                return null;
            };

            MockElement.prototype.insertAdjacentHTML = function(position, html) {
                this.html += html;
                if (this.owner && html.indexOf("NB-score-icon") !== -1) {
                    this.owner.iconOwners.push(this);
                }
            };

            var container = {
                marks: [],
                iconOwners: [],  // every element currently holding a score icon (mark or orphan)
                querySelectorAll: function(selector) {
                    if (selector === "mark[data-markjs]") {
                        return this.marks;
                    }
                    if (selector.indexOf("NB-score-icon") !== -1) {
                        var self = this;
                        return self.iconOwners.slice().map(function(owner) {
                            return {
                                parentNode: {
                                    removeChild: function() {
                                        var idx = self.iconOwners.indexOf(owner);
                                        if (idx !== -1) self.iconOwners.splice(idx, 1);
                                        owner.html = owner.html.replace(/NB-score-icon/g, "");
                                    }
                                }
                            };
                        });
                    }
                    return [];
                }
            };

            function resetMocks() {
                timeoutQueue = [];
                pendingMarks = [];
                container.marks = [];
                container.iconOwners = [];
            }

            function iconCount() {
                return container.iconOwners.length;
            }

            function totalIconCount() {
                return container.iconOwners.length;
            }

            var document = {
                getElementById: function(id) {
                    if (id === "NB-story") {
                        return container;
                    }
                    return null;
                },
                getElementsByClassName: function() {
                    return [];
                },
                elementFromPoint: function() {
                    return null;
                }
            };

            var window = {
                sampleText: true,
                location: "",
                pageYOffset: 0,
                console: { log: function() {} }
            };
            var console = window.console;

            function NoClickDelay() {}

            function JQueryStub() {}
            JQueryStub.prototype.live = function() { return this; };
            JQueryStub.prototype.each = function() { return this; };
            JQueryStub.prototype.bind = function() { return this; };
            JQueryStub.prototype.fitVids = function() { return this; };
            JQueryStub.prototype.closest = function() { return { length: 0 }; };
            JQueryStub.prototype.offset = function() { return { left: 0, top: 0, width: 0, height: 0 }; };
            JQueryStub.prototype.attr = function() { return ""; };
            JQueryStub.prototype.width = function() { return 0; };
            JQueryStub.prototype.height = function() { return 0; };
            JQueryStub.prototype.prop = function() { return ""; };
            JQueryStub.prototype.parent = function() { return this; };
            JQueryStub.prototype.addClass = function() { return this; };
            JQueryStub.prototype.removeClass = function() { return this; };
            JQueryStub.prototype.hasClass = function() { return false; };
            JQueryStub.prototype.contents = function() { return { unwrap: function() {} }; };

            function $(selector) {
                return new JQueryStub(selector);
            }
            $.scroll = function() {};

            function Zepto(callback) {
                if (callback) {
                    callback($);
                }
            }

            function Mark(ctx) {
                this.ctx = ctx;
            }

            Mark.prototype.unmark = function(opt) {
                // Mimic mark.js: unwrap <mark> elements but leave any child nodes
                // (including score icons) in the surrounding text flow.
                this.ctx.marks = [];
                if (opt && opt.done) {
                    opt.done();
                }
                return this;
            };

            Mark.prototype.mark = function(text, opt) {
                var ctx = this.ctx;
                pendingMarks.push(function() {
                    var el = new MockElement(opt.className, ctx);
                    ctx.marks.push(el);
                    if (opt.each) {
                        opt.each(el);
                    }
                });
                return this;
            };

            Mark.prototype.markRegExp = function(regex, opt) {
                var ctx = this.ctx;
                pendingMarks.push(function() {
                    var el = new MockElement(opt.className, ctx);
                    ctx.marks.push(el);
                    if (opt.each) {
                        opt.each(el);
                    }
                });
                return this;
            };
            """#
        )

        XCTAssertNil(context.exception)
        wait(for: [exceptionExpectation], timeout: 0.01)

        return context
    }
}
