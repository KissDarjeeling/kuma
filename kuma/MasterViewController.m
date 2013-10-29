//
//  MasterViewController.m
//  kuma
//
//  Created by Yumitaka Sugimoto on 2013/10/15.
//  Copyright (c) 2013年 Kyohei Kanetaka. All rights reserved.
//

#import "MasterViewController.h"

#import "DetailViewController.h"

#import "GTMOAuthAuthentication.h"

#import "GTMOAuthViewControllerTouch.h"

#import <Twitter/Twitter.h>

#import <Accounts/Accounts.h>


@interface MasterViewController () {
    //削除
    //NSMutableArray *_objects;
    
}
@end

@implementation MasterViewController {
    // OAuth認証オブジェクト
    GTMOAuthAuthentication *auth_;
    
    // 表示中ツイート情報
    NSArray *timelineStatuses_;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
}

// KeyChain登録サービス名
static NSString *const kKeychainAppServiceName = @"kuma";

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    ACAccountStore *accountStore = [[ACAccountStore alloc] init];
	ACAccountType *twitterAccountType = [accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    [accountStore requestAccessToAccountsWithType:twitterAccountType
                            withCompletionHandler:^(BOOL granted, NSError *error)
     {
         if (!granted) {
             NSLog(@"ユーザーがアクセスを拒否しました。");
         }else{
             NSArray *twitterAccounts = [accountStore accountsWithAccountType:twitterAccountType];
             if ([twitterAccounts count] > 0) {
                 ACAccount *account = [twitterAccounts objectAtIndex:0];
                 NSURL *url = [NSURL URLWithString:@"http://api.twitter.com/1/statuses/home_timeline.json"];
                 TWRequest *request = [[TWRequest alloc] initWithURL:url
                                                          parameters:nil
                                                       requestMethod:TWRequestMethodGET];
                 [request setAccount:account];
                 [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error)
                  {
                      if(!responseData){
                          NSLog(@"%@", error);
                      }else{
                          NSError* error; // 追加
                          NSArray *statuses = [NSJSONSerialization JSONObjectWithData:responseData // 追加
                                                                              options:NSJSONReadingMutableLeaves // 追加
                                                                                error:&error]; // 追加
                          if(statuses){
                              dispatch_async(dispatch_get_main_queue(), ^{ // 追加
                                  [self.tableView reloadData]; // 追加
                              }); // 追加
                          }else{ // 追加
                              NSLog(@"%@", error); // 追加
                          } // 追加
                      }
                  }];
             }
         }
     }];
	// Do any additional setup after loading the view, typically from a nib.
    
    //削除
    /*
     self.navigationItem.leftBarButtonItem = self.editButtonItem;
     
     UIBarButtonItem *addButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(insertNewObject:)];
     self.navigationItem.rightBarButtonItem = addButton;
     */
    
    //追加
    // GTMOAuthAuthenticationインスタンス生成
    // ※自分の登録アプリの Consumer Key と Consumer Secret に書き換えてください
    NSString *consumerKey = @"rt7piQ9DLQnWuYO5Xnbg";
    NSString *consumerSecret = @"gdd3Kjf5huUXljyzgVid6Eocbjp3n7H2k38QCdpPQ";
    auth_ = [[GTMOAuthAuthentication alloc]
             initWithSignatureMethod:kGTMOAuthSignatureMethodHMAC_SHA1
             consumerKey:consumerKey
             privateKey:consumerSecret];
    
    // 認証処理を実行
    //[self asyncSignIn];
    
    // 既にOAuth認証済みであればKeyChainから認証情報を読み込む
    BOOL authorized = [GTMOAuthViewControllerTouch
                       authorizeFromKeychainForName:kKeychainAppServiceName
                       authentication:auth_];
    if (authorized) {
        // 認証済みの場合はタイムライン更新
        [self asyncShowHomeTimeline];
        
        /*
         [NSTimer scheduledTimerWithTimeInterval:10.0
         target:self
         selector:@selector(asyncShowHomeTimeline)
         userInfo:nil
         repeats:YES];
         */
    } else {
        // 未認証の場合は認証処理を実施
        [self asyncSignIn];
    }
    
    /*
     [NSTimer scheduledTimerWithTimeInterval:10.0
     target:self
     selector:@selector(fetchGetHomeTimeline)
     userInfo:nil
     repeats:YES];
     */
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

// 認証処理
- (void)asyncSignIn
{
    NSString *requestTokenURL = @"https://api.twitter.com/oauth/request_token";
    NSString *accessTokenURL = @"https://api.twitter.com/oauth/access_token";
    NSString *authorizeURL = @"https://api.twitter.com/oauth/authorize";
    
    NSString *keychainAppServiceName = @"kuma";
    
    auth_.serviceProvider = @"Twitter";
    auth_.callback = @"http://www.example.com/OAuthCallback";
    
    GTMOAuthViewControllerTouch *viewController;
    viewController = [[GTMOAuthViewControllerTouch alloc]
                      initWithScope:nil
                      language:nil
                      requestTokenURL:[NSURL URLWithString:requestTokenURL]
                      authorizeTokenURL:[NSURL URLWithString:authorizeURL]
                      accessTokenURL:[NSURL URLWithString:accessTokenURL]
                      authentication:auth_
                      appServiceName:keychainAppServiceName
                      delegate:self
                      finishedSelector:@selector(authViewContoller:finishWithAuth:error:)];
    
    [[self navigationController] pushViewController:viewController animated:YES];
}

// 認証エラー表示AlertViewタグ
static const int kMyAlertViewTagAuthenticationError = 1;

// 認証処理が完了した場合の処理
- (void)authViewContoller:(GTMOAuthViewControllerTouch *)viewContoller
           finishWithAuth:(GTMOAuthAuthentication *)auth
                    error:(NSError *)error
{
    if (error != nil) {
        // 認証失敗
        NSLog(@"Authentication error: %d.", error.code);
        UIAlertView *alertView;
        alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                               message:@"Authentication failed."
                                              delegate:self
                                     cancelButtonTitle:@"Confirm"
                                     otherButtonTitles:nil];
        alertView.tag = kMyAlertViewTagAuthenticationError;
        [alertView show];
    } else {
        // 認証成功
        NSLog(@"Authentication succeeded.");
        // タイムライン表示
        [self asyncShowHomeTimeline];
    }
}

// UIAlertViewが閉じられた時
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // 認証失敗通知AlertViewが閉じられた場合
    if (alertView.tag == kMyAlertViewTagAuthenticationError) {
        // 再度認証
        [self asyncSignIn];
    }
}

// デフォルトのタイムライン処理表示
- (void)asyncShowHomeTimeline
{
    [self fetchGetHomeTimeline];
}

// タイムライン (home_timeline) 取得
- (void)fetchGetHomeTimeline
{
    // 要求を準備
    //NSURL *url = [NSURL URLWithString:@"http://api.twitter.com/1/statuses/home_timeline.json"];
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/statuses/home_timeline.json"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    
    // 要求に署名情報を付加
    [auth_ authorizeRequest:request];
    
    // 非同期通信による取得開始
    GTMHTTPFetcher *fetcher = [GTMHTTPFetcher fetcherWithRequest:request];
    [fetcher beginFetchWithDelegate:self
                  didFinishSelector:@selector(homeTimelineFetcher:finishedWithData:error:)];
}


// タイムライン (home_timeline) 取得応答時
- (void)homeTimelineFetcher:(GTMHTTPFetcher *)fetcher
           finishedWithData:(NSData *)data
                      error:(NSError *)error
{
    /*
     if (error != nil) {
     // タイムライン取得時エラー
     NSLog(@"Fetching status/home_timeline error: %d", error.code);
     return;
     }
     */
    
    // タイムライン取得成功
    // JSONデータをパース
    NSError *jsonError = nil;
    NSArray *statuses = [NSJSONSerialization JSONObjectWithData:data
                                                        options:0
                                                          error:&jsonError];
    
    // JSONデータのパースエラー
    if (statuses == nil) {
        NSLog(@"JSON Parser error: %d", jsonError.code);
        return;
    }
    
    // データを保持
    timelineStatuses_ = statuses;
    
    // テーブルを更新
    [self.tableView reloadData];
}



//---------------------------------------------------------------------------------------------------------
//削除
/*
 - (void)insertNewObject:(id)sender
 {
 if (!_objects) {
 _objects = [[NSMutableArray alloc] init];
 }
 [_objects insertObject:[NSDate date] atIndex:0];
 NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
 [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
 }
 
 */

#pragma mark - Table View
/*
 - (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
 {
 return 1;
 }
 
 - (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
 {
 //return _objects.count;
 //変更
 return 0;
 }
 
 
 - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
 {
 UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
 
 // コメントアウト
 //NSDate *object = _objects[indexPath.row];
 //cell.textLabel.text = [object description];
 return cell;
 }
 */
//---------------------------------------------------------------------------------------------------------



// テーブルのセクション数
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

// テーブルの行数
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [timelineStatuses_ count];
}

// 指定位置に挿入されるセルの要求
- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    
    // 対象インデックスのステータス情報を取り出す
    NSDictionary *status = [timelineStatuses_ objectAtIndex:indexPath.row];
    
    // ツイート本文を表示
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont systemFontOfSize:12];
    cell.textLabel.text = [status objectForKey:@"text"];
    
    // ユーザ情報から screen_name を取り出して表示
    NSDictionary *user = [status objectForKey:@"user"];
    cell.detailTextLabel.text = [user objectForKey:@"screen_name"];
    
    return cell;
}

// 指定位置の行で使用する高さの要求
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 対象インデックスのステータス情報を取り出す
    NSDictionary *status = [timelineStatuses_ objectAtIndex:indexPath.row];
    
    // ツイート本文をもとにセルの高さを決定
    NSString *content = [status objectForKey:@"text"];
    
    /*
     NSDictionary *stringAttributes = [ NSDictionary dictionaryWithObject:[UIFont systemFontOfSize:12] forKey:NSFontAttributeName];
     CGRect labelSize = [content boundingRectWithSize:CGSizeMake(300, 1000) options:NSStringDrawingUsesLineFragmentOrigin attributes:stringAttributes context:nil];
     
     return labelSize.size.height + 25;
     */
    
    CGSize labelSize = [content sizeWithFont:[UIFont systemFontOfSize:12]
                           constrainedToSize:CGSizeMake(300, 1000)
                               lineBreakMode:UILineBreakModeWordWrap];
    return labelSize.height + 25;
    
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

//---------------------------------------------------------------------------------------------------------
//削除
/*
 - (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
 {
 if (editingStyle == UITableViewCellEditingStyleDelete) {
 [_objects removeObjectAtIndex:indexPath.row];
 [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
 } else if (editingStyle == UITableViewCellEditingStyleInsert) {
 // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
 }
 }
 */


/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */

/*
 // Override to support conditional rearranging of the table view.
 - (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
 {
 // Return NO if you do not want the item to be re-orderable.
 return YES;
 }
 */

//削除
/*
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
 {
 if ([[segue identifier] isEqualToString:@"showDetail"]) {
 NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
 NSDate *object = _objects[indexPath.row];
 [[segue destinationViewController] setDetailItem:object];
 }
 }
 */

- (IBAction)pressComposeButton:(id)sender {
    if([TWTweetComposeViewController canSendTweet]){            // ツイートできるかどうかをチェックする
        TWTweetComposeViewController *composeViewController     //
        = [[TWTweetComposeViewController alloc] init];          // TWTweetComposeViewControllerオブジェクトを作成する
        [self presentModalViewController:composeViewController  //
                                animated:YES];                  // TWTweetComposeViewControllerオブジェクトを表示する
    }                                                           //
}
@end
