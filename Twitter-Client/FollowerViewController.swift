//
//  FollowerViewController.swift
//  Twitter-Client
//
//  Created by Ahmed Baracat on 7/12/16.
//  Copyright © 2016 Ahmed Baracat. All rights reserved.
//

import UIKit
import TwitterKit
import Alamofire
import AlamofireImage
import Argo
import ImageViewer

class FollowerViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    //Instatiate the image cache
    let imageCache = AutoPurgingImageCache()
    
    //The follower object for the ViewController
    var follower: User?
    
    //Tweets array to hold user tweets
    var tweets = [Tweet]()
    
    //To access the tapped image action for the overlay feature
    let helper = Helper()
    
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tweetsTableView: UITableView!
    @IBOutlet weak var profileImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Set the delegate of the tableView
        tweetsTableView.delegate = self
        tweetsTableView.dataSource = self
        
        //Set the title of the navigation bar
        title = follower?.name
        
        //Load the profile image from the db
        profileImageView.image = UIImage.loadImageFromDisk(follower!.profile_image_url)
        
        //Create a border width to distinguish the image from the banner
        profileImageView.layer.borderWidth = 3
        profileImageView.layer.borderColor = UIColor.whiteColor().CGColor
        
        //Set the banner image
        if let backgroundImageURL = follower?.profile_banner_url
        {
            backgroundImageView.image = UIImage.loadImageFromDisk(backgroundImageURL)
        }
        else
        {
            backgroundImageView.image = UIImage.loadImageFromDisk("")
        }
        
        //Profile image overlay action
        var tapGestureRecognizer = UITapGestureRecognizer(target:helper, action:Selector("imageTapped:"))
        profileImageView.addGestureRecognizer(tapGestureRecognizer)
        
        //Banner image overlay action
        tapGestureRecognizer = UITapGestureRecognizer(target:helper, action:Selector("imageTapped:"))
        backgroundImageView.addGestureRecognizer(tapGestureRecognizer)
        
        //To auto size the cell height
        tweetsTableView.rowHeight = UITableViewAutomaticDimension
        tweetsTableView.estimatedRowHeight = 140
        
        getTweets()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getTweets()
    {
        //Get the store of user sessions
        let store = Twitter.sharedInstance().sessionStore
        
        //Get the last user session
        let lastSession = store.session
        
        //Check if user was already logged in
        if let session = lastSession()
        {
            //Instantiate the Twitter client with the userID
            let client = TWTRAPIClient(userID: session.userID)
            
            let statusesShowEndpoint = "https://api.twitter.com/1.1/statuses/user_timeline.json"
            var clientError : NSError?
            
            //Add the cursor which indicates which page to fetch
            let params = ["count": "10", "include_rts": "1", "screen_name": follower!.screen_name]
            
            //Create the Twitter request to get the required http headers
            let twitterRequest = client.URLRequestWithMethod("GET", URL: statusesShowEndpoint, parameters: params, error: &clientError)
            
            //Create the Alamofire reuest
            let request = Alamofire.Manager.sharedInstance.request(twitterRequest)
            
            if(Reachability.isConnectedToNetwork())
            {
                //Initiate the request
                request.responseJSON { (response) in
                    if response.response?.statusCode == 200 {
                        
                        print("Success")
                        
                        //Cache the response
                        let cachedURLResponse = NSCachedURLResponse(response: response.response!, data: (response.data! as NSData), userInfo: nil, storagePolicy: .Allowed)
                        NSURLCache.sharedURLCache().storeCachedResponse(cachedURLResponse, forRequest: twitterRequest)
                        
                        //Parse the response
                        self.parseJson(response.data)
                    }
                    else {
                        
                        print("problem " + String(response))
                        
                        if let error = response.result.value as? NSDictionary
                        {
                            if let errorMessage = error.objectForKey("message") as? String
                            {
                                print("error: " + String(error) + "  errorMessage: " + String(errorMessage))
                            }
                        }
                    }
                }
            }
            else
            {
                if let response = NSURLCache.sharedURLCache().cachedResponseForRequest(twitterRequest)
                {
                    //Parse the response
                    self.parseJson(response.data)
                }
            }
        }
    }
    
    
    func parseJson(passedData: NSData?)
    {
        do {
            if let data = passedData
            {
                //Convert json String to foundation object
                let json: AnyObject? = try? NSJSONSerialization.JSONObjectWithData(data, options: [])
                
                if let j: AnyObject = json {
                    
                    //Map the foundation object to Response object
                    let response: [Tweet]? = decode(j)
                    
                    
                    //Add the tweets to tweets array
                    for tweet in response!
                    {
                        self.tweets.append(tweet)
                    }
                    
                    //Reload the tableView in order to display the newly added followers
                    self.tweetsTableView.reloadData()
                    
                }
            }
        } catch let jsonError as NSError {
            print("json error: \(jsonError.localizedDescription)")
        }
        
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let currentTweet = tweets[indexPath.row]
        
        let cell = tableView.dequeueReusableCellWithIdentifier("tweetCell", forIndexPath: indexPath) as! TweetTableViewCell
        
        cell.profileImageView?.image = profileImageView.image
        cell.tweetLabel?.text = currentTweet.text
        cell.nameLabel.text = follower?.name
        
        //Add placeholder image
        cell.tweetImageView.image = UIImage(named: "Placeholder")
        
        //If there is an image attached to the tweet
        if let url = currentTweet.entities?.media?.first?.media_url
        {
            //Check if there is an Internet conenction
            if(Reachability.isConnectedToNetwork())
            {
                //Check for the image in the cache
                if let image = imageCache.imageWithIdentifier(url)
                {
                    cell.tweetImageView.image = image
                }
                else
                {
                    //Fetch profile image
                    Alamofire.request(.GET, url)
                        .responseImage { response in
                            
                            if let image = response.result.value {
                                
                                //Apply the image to the correct cell
                                if let updateCell = tableView.cellForRowAtIndexPath(indexPath) as? TweetTableViewCell
                                {
                                    updateCell.tweetImageView.image = image
                                }
                                
                                //Cache the image
                                self.imageCache.addImage(image, withIdentifier: url)
                            }
                    }
                }
            }
            else
            {
                cell.tweetImageView.image = UIImage(named: "Placeholder")
            }
            
            //Reset the collapsing behavior
            cell.tweetImageTrailingConstraint.active = true
            cell.tweetImageView.alpha = 1
            
            cell.tweetImageBottomConstraint.constant = 8
            
        }
        else
        {
            //If no image is attached to the tweet
            //Collapse the imageView
            cell.tweetImageView.image = UIImage()
            cell.tweetImageTrailingConstraint.active = false
            cell.tweetImageView.alpha = 0
            
            //Make sure that space between cell and seperator is constant when we remove the image
            cell.tweetImageBottomConstraint.constant = 0
        }
        
        return cell
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tweets.count
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
     }
     */
    
}
