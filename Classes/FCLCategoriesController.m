#import "FCLCategoriesController.h"
#import "FCLBusinessFile.h"
#import "FCLCategory.h"
#import "FCLFormController.h"
#import "FCLUploader.h"
#import "FCLUpload.h"

@interface FCLCategoriesController () <UploaderDelegate>

@property(nonatomic,strong) IBOutlet UIView* loadingView;
@property(nonatomic,strong) IBOutlet UILabel* helpFooterView;

@end

@implementation FCLCategoriesController

@synthesize file;
@synthesize formController;

@synthesize username;
@synthesize password;

@synthesize loadingView;
@synthesize helpFooterView;


- (void) onSend:(FCLFormController*)form
{
    [self.navigationController popViewControllerAnimated:YES];
    
    FCLUpload* upload = [[FCLUpload alloc] init];
    
    [form.category saveDefaults];
    
    NSLog(@"Sending category %@ (%@) to business_file %@ (%@)", form.category.name, form.category.key, self.file.name, self.file.identifier);
    
    upload.fileId = self.file.identifier;
    upload.categoryKey = form.category.key;
    upload.fields = [form fields];
    upload.image = form.image;
    upload.username = self.username;
    upload.password = self.password;
    
    [[FCLUploader sharedUploader] addUpload:upload];
    
}


#pragma mark Lifecycle


- (void) viewDidLoad
{
    [super viewDidLoad];
    self.title = self.file.name;
    self.helpFooterView.text = NSLocalizedString(@"Insérez des photos et signatures sur votre application", @"");
}


- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [FCLUploader sharedUploader].delegate = self;
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [FCLUploader sharedUploader].delegate = nil;
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



#pragma mark UploaderDelegate


- (void) uploaderDidUpdateStatus:(FCLUploader *)anUploader
{
    NSLog(@"uploaderDidUpdateStatus: isUploading: %d", (int)[anUploader isUploading]);
    [self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.0];
}




#pragma mark UITableViewDataSource



- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView
{
    return 1; // ([[Uploader sharedUploader] isUploading] ? 2 : 1);
}


- (NSInteger)tableView:(UITableView*)aTableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return self.file ? [self.file.categories count] : 0;
    if (section == 1) return 1;
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:@"CategoryName"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"CategoryName"];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
        cell.textLabel.text = [[self.file.categories objectAtIndex:indexPath.row] name];
        
        return cell;
    } else {
        UITableViewCell *cell = [aTableView dequeueReusableCellWithIdentifier:@"Loading"];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Loading"];
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.textLabel.text = @"Téléchargement...";
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
        return cell;
    }
}

#pragma mark UITableViewDelegate


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0)
    {
        self.formController = [[FCLFormController alloc] initWithNibName:nil bundle:nil];
        formController.category = [self.file.categories objectAtIndex:indexPath.row];
        [formController.category reset];
        [formController.category loadDefaults];
        formController.target = self;
        formController.action = @selector(onSend:);
        [self.navigationController pushViewController:formController animated:YES];
    }
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if ([[FCLUploader sharedUploader] isUploading])
    {
        return 32.0;
    }
    else
    {
        return 0.0;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if ([[FCLUploader sharedUploader] isUploading])
    {
        return self.loadingView;
    }
    else
    {
        return nil;
    }
    
}


@end
