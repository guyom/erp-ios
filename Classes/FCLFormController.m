#import "FCLFormController.h"
#import "FCLCategory.h"
#import "FCLField.h"
#import "FCLOptionsController.h"
#import "FCLSignatureViewController.h"
#import "UIImage+OAImageResize.h"
#import <QuartzCore/QuartzCore.h>

@interface FCLFormController () <UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property(nonatomic, strong) NSOperationQueue* operationQueue;
@property(nonatomic, strong) NSInvocationOperation* resizingOperation;
@property(nonatomic, strong) IBOutlet UIImageView* imageView;
@property(nonatomic, strong) UIImagePickerController* picker;
@property(nonatomic, strong) UIImage* resizedImage;
@property(nonatomic, strong) UIImage* signatureImage;

@end

@implementation FCLFormController {
    BOOL cameraDidCancel;
}

- (NSOperationQueue*) operationQueue
{
    if (!_operationQueue)
    {
        self.operationQueue = [NSOperationQueue new];
    }
    return _operationQueue;
}

- (NSArray*) fields
{
    return self.category.fields;
}

// MARK: Lifecycle
- (void) dealloc
{
    [self.operationQueue cancelAllOperations];
}

- (void) viewDidLoad
{
    [super viewDidLoad];
    if (self.image)
    {
        NSLog(@"form view was reloaded. setting image to imageView");
    }
    self.title = self.category.name;
    self.imageView.image = self.image ?: [UIImage imageNamed:@"FCLPhotoPlaceholder.png"];
}

// MARK: Rotation

- (UIInterfaceOrientationMask) supportedInterfaceOrientations
{
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
        return UIInterfaceOrientationMaskAllButUpsideDown;
    return UIInterfaceOrientationMaskPortrait;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation
{
    return UIInterfaceOrientationPortrait;
}

- (BOOL) shouldAutorotate
{
    return YES;
}

// MARK: Handlers

- (void) onCancel
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) presentImagePickerWithSourceType:(UIImagePickerControllerSourceType) type
{
    self.picker = [[UIImagePickerController alloc] init];
    
    if ([UIImagePickerController isSourceTypeAvailable:type])
    {
        self.picker.sourceType = type;
    }
    else
    {
        self.picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    }
    
    if (type == UIImagePickerControllerSourceTypePhotoLibrary)
    {
        self.picker.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
    }
    
    self.picker.delegate = self;
    self.picker.allowsEditing = NO;
    [self presentViewController:self.picker animated:YES completion:nil];
}

- (void) presentImagePicker
{
    [self presentImagePickerWithSourceType:UIImagePickerControllerSourceTypeCamera];
}

- (void) resizeImageInBackground:(UIImage*)anImage
{
    @autoreleasepool {
        UIImage* aResizedImage = [anImage OAImageScaledToFitWidth:800.0];
        // I do not use performSelectorOnMainThread because it happens in a cycle after waitUntilAllOperationsAreFinished
        //[self performSelectorOnMainThread:@selector(setResizedImage:) withObject:aResizedImage waitUntilDone:NO];
        @synchronized(self)
        {
            self.resizedImage = aResizedImage;
        }
    }
}



#pragma mark - UIImagePickerControllerDelegate


- (void)imagePickerController:(UIImagePickerController*)aPicker didFinishPickingMediaWithInfo:(NSDictionary*)info
{
    self.image = [info objectForKey:UIImagePickerControllerOriginalImage];
    
    if (!self.image)
    {
        NSLog(@"FormController: no picture returned to the delegate!");
        return;
    }
    
    [self.operationQueue waitUntilAllOperationsAreFinished];
    self.resizingOperation = nil;
    self.resizingOperation = [[NSInvocationOperation alloc]
                              initWithTarget:self
                              selector:@selector(resizeImageInBackground:)
                              object:self.image];
    [self.operationQueue addOperation:self.resizingOperation];
    [self.imageView setImage:self.image];
    [self.tableView reloadData];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController*)aPicker
{
    cameraDidCancel = YES;
    [self dismissViewControllerAnimated:YES completion:nil];
}




#pragma mark - UITableViewDataSource



- (BOOL) showExtraFieldForPicture
{
    return [self.category wantsUploadPicture];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)aTableView
{
    return (self.category.fields ? [self.category.fields count] : 0) + ([self showExtraFieldForPicture] ? 1 : 0) + 1;
}

- (NSString*) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section < self.fields.count)
    {
        return [[self.fields objectAtIndex:section] name];
    }
    else if (section == self.fields.count && [self showExtraFieldForPicture])
    {
        return NSLocalizedString(@"Photo", @"");
    }
    return nil;  // preview or send button
}

- (NSInteger) tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section
{
    if (section < self.fields.count)
    {
        FCLField* field = [self.fields objectAtIndex:section];
        if ([field isEnum])
        {
            return 1; // we display a navigation controller to select from the list
        }
        else if ([field isSignature])
        {
            return 2;
        }
        else
        {
            return 1;
        }
    }
    else if (section == self.fields.count && [self showExtraFieldForPicture]) // preview
    {
        // if there's no camera, do not show redundant photo library button; we'll show photo library anyways
        return ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera] ? 2 : 1);
    }
    else // send button
    {
        return 1;
    }
}

- (NSString*) reuseIdentifierForIndexPath:(NSIndexPath*)indexPath
{
    NSUInteger size = self.fields.count;
    if (indexPath.section < size)
    {
        return [self.fields[indexPath.section] key];
    }
    else if (indexPath.section == size && [self showExtraFieldForPicture])
    {
        return @"Preview";
    }
    else
    {
        return @"Button";
    }
}

- (UITableViewCell*) tableView:(UITableView*)aTableView cellForRowAtIndexPath:(NSIndexPath*)indexPath
{
    NSString* cellIdentifier = [self reuseIdentifierForIndexPath:indexPath];
    UITableViewCell* cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    
    cell.backgroundColor = [UIColor whiteColor];
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    
    cell.accessoryType = UITableViewCellAccessoryNone;
    CGSize cellSize = cell.contentView.frame.size;
    
    // clean up recycled cell from field elements
    for (UIView* view in [cell.contentView subviews])
    {
        [view removeFromSuperview];
    }
    
    if (indexPath.section < self.fields.count)
    {
        FCLField* field = (FCLField*)[self.fields objectAtIndex:indexPath.section];
        
        if ([field isEnum])
        {
            cell.textLabel.text = [field value] ? [field.valueTitles objectAtIndex:field.enumSelectionIndex] : @"";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        else if ([field isSignature])
        {
            if (indexPath.row == 0)
            {
                cell.textLabel.numberOfLines = 3;
                cell.textLabel.text = field.fieldDescription ?: @"";
                cell.textLabel.font = [UIFont systemFontOfSize:16.0];
                cell.textLabel.textAlignment = NSTextAlignmentLeft;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            else
            {
                cell.textLabel.text = NSLocalizedString(@"Signer", @"");
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                
                if (self.signatureImage)
                {
                    cell.textLabel.text = NSLocalizedString(@"Signé", @"");
                    cell.textLabel.textColor = [UIColor colorWithRed:0.2 green:0.5 blue:0.0 alpha:1.0];
                    cell.textLabel.font = [UIFont systemFontOfSize:20.0];
                }
            }
        }
        else
        {
            UIView* uifield = nil;
            if ([field isString] || [field isNumeric])
            {
                uifield = field.textField;
                [uifield setFrame:CGRectInset(CGRectMake(0, 0, cellSize.width, cellSize.height), 10.0, 0.0)];
            }
            else
            {
                uifield = field.textView;
                [uifield setFrame:CGRectInset(CGRectMake(0, 0, cellSize.width, cellSize.height), 1.0, 5.0)];
            }
            [cell.contentView addSubview:uifield];
        }
    }
    else if (indexPath.section == [self.fields count] && [self showExtraFieldForPicture]) // preview cell
    {
        if (indexPath.row == 0)
        {
            //cell.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
            //cell.backgroundColor = [UIColor colorWithPatternImage:self.image];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (self.imageView)
            {
                [self.imageView setFrame:CGRectInset(CGRectMake(0, 0, cellSize.width, cellSize.height), 0.0, 10.0)];
                [cell.contentView addSubview:self.imageView];
            }
        }
        else if (indexPath.row == 1)
        {
            cell.textLabel.text = NSLocalizedString(@"Albums Photo", @"");
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    }
    else // send button
    {
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor blackColor];
        cell.textLabel.text = NSLocalizedString(@"Envoyer", @"");
    }
    
    return cell;
}




#pragma mark - UITableViewDelegate


- (CGFloat)tableView:(UITableView *)aTableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section < [self.fields count])
    {
        FCLField* field = [self.fields objectAtIndex:indexPath.section];
        
        if ([field isText])
        {
            return 132.0;
        }
        if ([field isSignature] && indexPath.row == 0)
        {
            return 70.0;
        }
        return 44.0;
    }
    else if (indexPath.section == [self.fields count] && [self showExtraFieldForPicture]) // preview
    {
        if (indexPath.row == 0)
        {
            if (self.image)
            {
                if (self.image.size.height < self.image.size.width)
                {
                    return (CGFloat)round((double)(300.0*self.image.size.height/self.image.size.width));
                }
                else
                {
                    return 200.0;
                }
            }
            return 100.0;
        }
        else
        {
            return 44.0;
        }
    }
    else // send button
    {
        return 44.0;
    }
}

- (void) tableView:(UITableView*)tableView didSelectRowAtIndexPath:(NSIndexPath*)indexPath
{
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
    if (indexPath.section < [self.fields count])
    {
        FCLField* field = [self.fields objectAtIndex:indexPath.section];
        if ([field isEnum])
        {
            FCLOptionsController* optionsController = [[FCLOptionsController alloc] initWithNibName:nil bundle:nil];
            optionsController.field = field;
            optionsController.target = self;
            optionsController.action = @selector(optionsControllerDidFinish:);
            [self.navigationController pushViewController:optionsController animated:YES];
        }
        else if ([field isSignature])
        {
            FCLSignatureViewController* vc = [[FCLSignatureViewController alloc] initWithNibName:nil bundle:nil];
            
            [vc view]; // preload the view
            vc.descriptionLabel.text = field.fieldDescription ?: @"";
            
            vc.completionBlock = ^(UIImage* image){
                self.signatureImage = image;
                field.image = image;
                [self dismissViewControllerAnimated:YES completion:nil];
                [self.tableView reloadData];
            };
            
            UINavigationController* nc = [[UINavigationController alloc] initWithRootViewController:vc];
            [self presentViewController:nc animated:YES completion:nil];
        }
    }
    else if (indexPath.section == [self.fields count] && [self showExtraFieldForPicture])
    {
        if (indexPath.row == 0)
        {
            [self presentImagePicker];
        }
        else if (indexPath.row == 1)
        {
            [self presentImagePickerWithSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
        }
    }
    else
    {
        if (self.image || [self.category hasSignatureField])
        {
            [self.operationQueue waitUntilAllOperationsAreFinished];
            
            if (self.resizedImage)
            {
                self.image = self.resizedImage;
            }
            
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
//#warning Replace this with a block to make it safe and nice.
            [self.target performSelector:self.action withObject:self];
#pragma clang diagnostic pop
        }
        else 
        {
            [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
            [self presentImagePicker];
        }
    }
}





#pragma mark - OptionsController

- (void) optionsControllerDidFinish:(FCLOptionsController*)optionsController
{
    [self.tableView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}



@end
