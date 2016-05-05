//
//  AppDelegate.swift
//  alexa-location-finder
//
//  Created by Andrew Monshizadeh on 4/9/16.
//  Copyright (c) 2016 amonshiz. All rights reserved.
//


import UIKit
import AWSSNS


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        let credentials = AWSStaticCredentialsProvider(accessKey:"YOUR_ACCESS_KEY", secretKey:"YOUR_SECRET_KEY")
        let serviceConfiguration = AWSServiceConfiguration(region: AWSRegionType.USEast1, credentialsProvider: credentials)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = serviceConfiguration

        application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: .Alert, categories: nil))
        application.registerForRemoteNotifications()

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    @available(iOS 3.0, *) func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let deviceTokenString = "\(deviceToken)"
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString: "<>"))
            .stringByReplacingOccurrencesOfString(" ", withString: "")
        NSUserDefaults.standardUserDefaults().setObject(deviceTokenString, forKey: "deviceToken")

        let sns = AWSSNS.defaultSNS()
        let request = AWSSNSCreatePlatformEndpointInput()
        request.token = deviceTokenString
        request.platformApplicationArn = "YOUR_AWSSNS_ARN_STRING"

        let createTask: AWSTask = sns.createPlatformEndpoint(request)
        createTask.continueWithExecutor(AWSExecutor.mainThreadExecutor(), withBlock: { (task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                print("Error: \(task.error)")
                return nil
            }

            let createEndpointResponse = task.result as! AWSSNSCreateEndpointResponse
            NSUserDefaults.standardUserDefaults().setObject(createEndpointResponse.endpointArn, forKey: "endpointArn")

            return nil
        })
    }

    @available(iOS 3.0, *) func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        print ("Error registering: \(error.localizedDescription)")
    }

    @available(iOS 3.0, *) func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject:AnyObject]) {
        print("remote notification user info: \(userInfo)")
    }

    @available(iOS 7.0, *) func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject:AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        print("application:didReceiveRemoteNotification:fetchCompletionHandler: \(userInfo)")

        let localNotification = UILocalNotification()
        localNotification.alertBody = "Location request made"
        application.presentLocalNotificationNow(localNotification)

        LocationManager.getCurrentLocation { location in
            print("location: \(location)")

            guard let loc = location else {
                completionHandler(UIBackgroundFetchResult.NoData)
                return
            }
            guard let aps = userInfo["aps"] as? [String:AnyObject],
                endpoint = aps["endpoint"] as? String else {
                    completionHandler(UIBackgroundFetchResult.NoData)
                    return
            }
            guard let url = NSURL(string: "YOUR_SERVER_URL/IP_ADDRESS" + endpoint) else {
                completionHandler(UIBackgroundFetchResult.NoData)
                return
            }

            let request = NSMutableURLRequest(URL: url)
            request.HTTPMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String:String] = ["location": "\(loc.coordinate.latitude),\(loc.coordinate.longitude)"]
            do {
                let bodyData = try NSJSONSerialization.dataWithJSONObject(body as AnyObject, options: [])
                let bodyUnserialized = String(data: bodyData, encoding: NSUTF8StringEncoding)
                print("bodyUnserialized: \(bodyUnserialized)")

                let task = NSURLSession.sharedSession().uploadTaskWithRequest(request, fromData: bodyData) { (data, res, error) in
                    completionHandler(UIBackgroundFetchResult.NewData)
                }
                task.resume()
            } catch (let e) {
                print("caught: \(e)")
                completionHandler(UIBackgroundFetchResult.NoData)
                return
            }
        }
    }

}
