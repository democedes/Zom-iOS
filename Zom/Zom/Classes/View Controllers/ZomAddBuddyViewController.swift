//
//  ZomAddBuddyViewController.swift
//  Zom
//
//  Created by N-Pex on 2015-11-18.
//
//

import UIKit
import ChatSecureCore

public class ZomAddBuddyViewController: UIViewController, QRCodeReaderDelegate, OTRNewBuddyViewControllerDelegate, MFMessageComposeViewControllerDelegate {
    
    @IBOutlet weak var segmentedControl: UISegmentedControl!
    public var account:OTRAccount? = nil
    @IBOutlet weak var containerView: UIView!
    
    var shareLink:String? = nil
    var pageController:UIPageViewController?

    var startingTabIndex:Int = -1
    var previousSegmentedControlIndex:Int = 0
    var vcAdd:ZomNewBuddyViewController? = nil
    var vcQR:UIViewController? = nil
    var vcMyQR:ZomMyQRViewController? = nil
    var lastScannedQR:String? = nil
    
    init(accountId : String) {
        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ZomTheme().lightThemeColor
        //[self createContentPages];
        
        
        //NSDictionary *options = [NSDictionary dictionaryWithObject:
        //[NSNumber numberWithInteger:UIPageViewControllerSpineLocationMin]
        //forKey: UIPageViewControllerOptionSpineLocationKey];
        pageController = UIPageViewController(transitionStyle: UIPageViewControllerTransitionStyle.Scroll, navigationOrientation: UIPageViewControllerNavigationOrientation.Horizontal, options: nil)
        //pageController.dataSource = self
        pageController!.view.frame = self.containerView.frame
        //pageController!.view.removeConstraints(pageController!.view.constraints)
        //pageController!.view.addConstraints(self.containerView.constraints)
        
        vcAdd = self.storyboard?.instantiateViewControllerWithIdentifier("newBuddyViewController") as? ZomNewBuddyViewController
        vcAdd?.account = account!
        vcAdd!.delegate = self
        vcAdd!.showSmsButton(MFMessageComposeViewController.canSendText())
        if (!QRCodeReader.supportsMetadataObjectTypes([AVMetadataObjectTypeQRCode])) {
            vcQR = self.storyboard!.instantiateViewControllerWithIdentifier("enableCameraViewController")
            let status = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
            if (status == AVAuthorizationStatus.NotDetermined) {
                AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { (enabled) in
                    if (enabled) {
                        self.createQRViewController()
                        self.segmentedControlValueChanged(self.segmentedControl)
                    }
                })
            }
        } else {
            createQRViewController()
        }
        vcMyQR = self.storyboard!.instantiateViewControllerWithIdentifier("myQR") as? ZomMyQRViewController
        
        var types = Set<NSNumber>()
        types.insert(NSNumber(int: OTRFingerprintType.OTR.rawValue))
        self.account!.generateShareURLWithFingerprintTypes(types, completion: { (url, error) -> Void in
            if (url != nil && error == nil) {
                self.shareLink = url.absoluteString
                self.vcMyQR!.setQRString(self.shareLink)
            } else {
                self.segmentedControl.removeSegmentAtIndex(2, animated: false)
            }
        })
        
        pageController?.setViewControllers([vcAdd!], direction: UIPageViewControllerNavigationDirection.Forward, animated: true, completion: nil)

        self.addChildViewController(pageController!)
        self.view.addSubview(pageController!.view)
        pageController?.didMoveToParentViewController(self)
    }
    
    private func createQRViewController() {
        vcQR = QRCodeReaderViewController()
        (vcQR as! QRCodeReaderViewController).delegate = self
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pageController!.view.frame = self.containerView.frame
        // Starting on a particular tab? Switch to that here.
        if (self.startingTabIndex != -1) {
            self.segmentedControl.selectedSegmentIndex = self.startingTabIndex
            self.segmentedControlValueChanged(self.segmentedControl)
            self.startingTabIndex = -1
        }
    }

    @IBAction func cancelButtonPressed(sender: AnyObject) {
        self.navigationController?.popViewControllerAnimated(true)
    }
    
    @IBAction func addButtonPressed(sender: AnyObject) {
        
        if (self.segmentedControl.selectedSegmentIndex == 0) {
            let vc:OTRNewBuddyViewController = pageController!.viewControllers![0] as! OTRNewBuddyViewController
            vc.performSelector(Selector("doneButtonPressed:"), withObject: self)
        }
    }

    @IBAction func shareSmsButtonPressed(sender: AnyObject) {
        if (self.shareLink != nil) {
            let messageComposeViewController:MFMessageComposeViewController = MFMessageComposeViewController()
            messageComposeViewController.body = self.shareLink
            messageComposeViewController.messageComposeDelegate = self
            self.navigationController!.presentViewController(messageComposeViewController, animated: true, completion: nil)
        }
    }
    
    @IBAction func shareButtonPressed(sender: AnyObject) {
        ShareController.shareAccount(self.account!, sender: sender, viewController: self)
    }
    
    @IBAction func segmentedControlValueChanged(sender: AnyObject) {
        
        var direction:UIPageViewControllerNavigationDirection = UIPageViewControllerNavigationDirection.Forward
        if (self.segmentedControl.selectedSegmentIndex < self.previousSegmentedControlIndex) {
            direction = UIPageViewControllerNavigationDirection.Reverse
        }
        
        self.previousSegmentedControlIndex = self.segmentedControl.selectedSegmentIndex

        if (self.segmentedControl.selectedSegmentIndex == 0) {
            pageController?.setViewControllers([vcAdd!], direction: direction, animated: true, completion: nil)
            pageController!.view.frame = self.containerView.frame
            vcAdd!.view.frame = pageController!.view.bounds
        } else if (self.segmentedControl.selectedSegmentIndex == 1) {
            pageController?.setViewControllers([vcQR!], direction: direction, animated: true, completion: nil)
            pageController!.view.frame = self.containerView.frame
            vcQR!.view.frame = pageController!.view.bounds
        } else if (self.segmentedControl.selectedSegmentIndex == 2) {
            pageController?.setViewControllers([vcMyQR!], direction: direction, animated: true, completion: nil)
            pageController!.view.frame = self.containerView.frame
            vcMyQR!.view.frame = pageController!.view.bounds
        }
    }

    public func readerDidCancel(reader:QRCodeReaderViewController) {
        self.segmentedControl.selectedSegmentIndex = 0
        self.segmentedControlValueChanged(self.segmentedControl)
    }
    
    public func reader(reader:QRCodeReaderViewController, didScanResult result:String) {
        if (self.lastScannedQR == nil || result.compare(self.lastScannedQR!) != NSComparisonResult.OrderedSame) {
            self.lastScannedQR = result
            vcAdd!.populateFromQRResult(result)
            vcAdd!.performSelector(Selector("doneButtonPressed:"), withObject: self)
        }
    }
    
    public func controller(viewController: OTRNewBuddyViewController!, didAddBuddy buddy: OTRBuddy!) {
        // TODO - enter conversation with newly added buddy
        self.cancelButtonPressed(self) // Close
        if let appDelegate = UIApplication.sharedApplication().delegate as? OTRAppDelegate {
            appDelegate.splitViewCoordinator.enterConversationWithBuddy(buddy.uniqueId)
        }
    }
    
    public func shouldDismissViewController(viewController: OTRNewBuddyViewController!) -> Bool {
        self.cancelButtonPressed(self) // Close
        return false
    }
    
    public func messageComposeViewController(controller: MFMessageComposeViewController, didFinishWithResult result: MessageComposeResult) {
        controller.dismissViewControllerAnimated(true, completion: nil)
    }
    
    public func showQRTab() -> Void {
        self.startingTabIndex = 1
    }
    
    @IBAction func enableCameraButtonPressed(sender: AnyObject) {
        if let settingsURL = NSURL(string: UIApplicationOpenSettingsURLString) {
            UIApplication.sharedApplication().openURL(settingsURL)
        }
    }
}