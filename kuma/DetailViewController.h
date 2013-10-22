//
//  DetailViewController.h
//  kuma
//
//  Created by KissDarjeeling on 2013/10/22.
//  Copyright (c) 2013年 user. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
