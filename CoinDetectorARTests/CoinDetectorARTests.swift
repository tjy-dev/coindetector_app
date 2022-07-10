//
//  CoinDetectorARTests.swift
//  CoinDetectorARTests
//
//  Created by YUKITO on 2022/06/16.
//

import XCTest
@testable import CoinDetectorAR

class CoinDetectorARTests: XCTestCase {

    var viewController: ViewController!
    
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        self.viewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as? ViewController
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        viewController.loadViewIfNeeded()
        let a = CGRect(x: 0, y: 0, width: 100, height: 100)
        let b = CGRect(x: 50, y: 50, width: 100, height: 100)
        let c = CGRect(x: 50, y: 100, width: 100, height: 100)
        let d = CGRect(x: 100, y: 50, width: 100, height: 100)
        let e = CGRect(x: 100, y: 100, width: 100, height: 100)
        let res1 = viewController.intersects(a, b)
        let res2 = viewController.intersects(a, c)
        let res3 = viewController.intersects(a, d)
        let res4 = viewController.intersects(a, e)
        XCTAssertEqual(res1, true)
        XCTAssertEqual(res2, false)
        XCTAssertEqual(res3, false)
        XCTAssertEqual(res4, false)
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
