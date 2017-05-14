#import "QIRootListController.h"
#import <Preferences/PSSpecifier.h>

#include <objc/runtime.h>
#include <notify.h>

#import "../Global.h"

static NSString *shortcutForImageSelection = nil;

@interface PSSpecifier (QuickImages)
- (void)setButtonAction:(SEL)arg1;
@end

static void triggerPreferencesReload() {
	notify_post("com.noahsaso.quickimages.pn");
}

static PSSpecifier *createButtonSpecifier(NSString *title, id controller, SEL action) {
	PSSpecifier *specifier = [objc_getClass("PSSpecifier") preferenceSpecifierNamed:title target:controller set:nil get:nil detail:nil cell:PSButtonCell edit:nil];
	[specifier setButtonAction:action];
	return specifier;
}

static NSArray *createSpecifierArrayForShortcutWithController(NSString *shortcut, id controller) {
	PSSpecifier *groupSpecifier = [objc_getClass("PSSpecifier") groupSpecifierWithName:shortcut];
	[groupSpecifier setProperty:groupSpecifier forKey:@"GroupSpecifier"];

	PSSpecifier *changeNameActionSpecifier = createButtonSpecifier(@"Change Trigger", controller, @selector(changeShortcutTrigger:));
	[changeNameActionSpecifier setProperty:groupSpecifier forKey:@"GroupSpecifier"];
	
	PSSpecifier *viewImageActionSpecifier = createButtonSpecifier(@"View Image", controller, @selector(viewShortcutImage:));
	[viewImageActionSpecifier setProperty:groupSpecifier forKey:@"GroupSpecifier"];

	PSSpecifier *setImageActionSpecifier = createButtonSpecifier(@"Set Image", controller, @selector(setShortcutImage:));
	[setImageActionSpecifier setProperty:groupSpecifier forKey:@"GroupSpecifier"];

	PSSpecifier *removeShortcutActionSpecifier = createButtonSpecifier(@"Remove Shortcut", controller, @selector(removeShortcut:));
	[removeShortcutActionSpecifier setProperty:groupSpecifier forKey:@"GroupSpecifier"];

	return @[groupSpecifier, changeNameActionSpecifier, viewImageActionSpecifier, setImageActionSpecifier, removeShortcutActionSpecifier];
}

@implementation QIRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
		NSMutableArray *mutableSpecifiers = [_specifiers mutableCopy];
		for(NSString *shortcut in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:SHORTCUTS_PATH error:nil]) {
			[mutableSpecifiers addObjectsFromArray:createSpecifierArrayForShortcutWithController(shortcut, self)];
		}
		_specifiers = [mutableSpecifiers copy];
	}
	return _specifiers;
}

- (void)addNewShortcut {
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"QuickImages" message:@"Please enter your new shortcut trigger (case insensitive)" preferredStyle:UIAlertControllerStyleAlert];
	[alertController addTextFieldWithConfigurationHandler: ^(UITextField *textField) {
		textField.placeholder = @"Shortcut Trigger";
	}];
	[alertController addAction:[UIAlertAction actionWithTitle:@"Create" style:UIAlertActionStyleDefault handler: ^(UIAlertAction *action) {
		NSString *shortcut = [alertController.textFields[0].text lowercaseString];
		HBLogDebug(@"Creating %@...", shortcut);
		NSArray *specifierArray = createSpecifierArrayForShortcutWithController(shortcut, self);
		[self addSpecifiersFromArray:specifierArray animated:YES];
		if(![[NSFileManager defaultManager] fileExistsAtPath:PATH_FOR_SHORTCUT(shortcut)]) {
			[[NSFileManager defaultManager] createFileAtPath:PATH_FOR_SHORTCUT(shortcut) contents:nil attributes:nil];
		}
		triggerPreferencesReload();
		[self setShortcutImage:specifierArray[3]];
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler: ^(UIAlertAction *action) {
		HBLogDebug(@"Cancelled");
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

- (void)changeShortcutTrigger:(PSSpecifier *)specifier {
	NSString *shortcut = [(PSSpecifier *)[specifier propertyForKey:@"GroupSpecifier"] name];
	HBLogDebug(@"Changing trigger for %@...", shortcut);
	UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"QuickImages" message:@"Please enter your changed shortcut trigger (case insensitive)" preferredStyle:UIAlertControllerStyleAlert];
	[alertController addTextFieldWithConfigurationHandler: ^(UITextField *textField) {
		textField.placeholder = @"New Shortcut Trigger";
	}];
	[alertController addAction:[UIAlertAction actionWithTitle:@"Change" style:UIAlertActionStyleDefault handler: ^(UIAlertAction *action) {
		NSString *newShortcut = alertController.textFields[0].text;
		HBLogDebug(@"Changing %@ to %@...", shortcut, newShortcut);
		PSSpecifier *groupSpecifier = [self specifierAtIndex:([self indexOfSpecifier:specifier] - 1)];
		[groupSpecifier setName:newShortcut];
		[self reloadSpecifier:groupSpecifier animated:YES];
		if([[NSFileManager defaultManager] fileExistsAtPath:PATH_FOR_SHORTCUT(shortcut)]) {
			[[NSFileManager defaultManager] moveItemAtPath:PATH_FOR_SHORTCUT(shortcut) toPath:PATH_FOR_SHORTCUT(newShortcut) error:nil];
			triggerPreferencesReload();
		}
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler: ^(UIAlertAction *action) {
		HBLogDebug(@"Cancelled");
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

- (void)viewShortcutImage:(PSSpecifier *)specifier {
	NSString *shortcut = [(PSSpecifier *)[specifier propertyForKey:@"GroupSpecifier"] name];
	HBLogDebug(@"Viewing image for %@...", shortcut);
	NSString *imagePath = PATH_FOR_SHORTCUT(shortcut);
	if([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
		UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
		if(image != nil) {
			UIView *backgroundView = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
			backgroundView.backgroundColor = [UIColor colorWithWhite:0.f alpha:0.8f];
			backgroundView.alpha = 0.f;
			[backgroundView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismissPreview:)]];

			UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 30.f, [UIScreen mainScreen].bounds.size.width, 30.f)];
			titleLabel.userInteractionEnabled = NO;
			titleLabel.text = [NSString stringWithFormat:@"Preview for shortcut '%@'", [shortcut uppercaseString]];
			titleLabel.font = [UIFont systemFontOfSize:22.f];
			titleLabel.textColor = UIColor.whiteColor;
			titleLabel.textAlignment = NSTextAlignmentCenter;
			[backgroundView addSubview:titleLabel];

			UILabel *dismissLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.f, 65.f, [UIScreen mainScreen].bounds.size.width, 30.f)];
			dismissLabel.userInteractionEnabled = NO;
			dismissLabel.text = @"Tap anywhere to dismiss";
			dismissLabel.font = [UIFont systemFontOfSize:19.f];
			dismissLabel.textColor = UIColor.whiteColor;
			dismissLabel.textAlignment = NSTextAlignmentCenter;
			[backgroundView addSubview:dismissLabel];

			UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(30.f, 115.f, [UIScreen mainScreen].bounds.size.width - 60.f, [UIScreen mainScreen].bounds.size.height - 145.f)];
			imageView.userInteractionEnabled = NO;
			imageView.contentMode = UIViewContentModeScaleAspectFit;
			imageView.image = image;
			[backgroundView addSubview:imageView];

			[[UIApplication sharedApplication].keyWindow addSubview:backgroundView];

			[UIView animateWithDuration:0.3f animations:^{
				backgroundView.alpha = 1.f;
			}];
		}
	}
}

- (void)dismissPreview:(UITapGestureRecognizer *)tapGestureRecognizer {
	[UIView animateWithDuration:0.3f animations:^{
		tapGestureRecognizer.view.alpha = 0.f;
	} completion: ^(BOOL finished){
		[tapGestureRecognizer.view removeFromSuperview];
	}];
}

- (void)setShortcutImage:(PSSpecifier *)specifier {
	NSString *shortcut = [(PSSpecifier *)[specifier propertyForKey:@"GroupSpecifier"] name];
	HBLogDebug(@"Changing image for %@...", shortcut);
	UIImagePickerController *pickerController = [UIImagePickerController new];
	pickerController.delegate = self;
	pickerController.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
	pickerController.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType: pickerController.sourceType];
	shortcutForImageSelection = shortcut;
	[self presentViewController:pickerController animated:YES completion:nil];
}

- (void)removeShortcut:(PSSpecifier *)specifier {
	PSSpecifier *groupSpecifier = (PSSpecifier *)[specifier propertyForKey:@"GroupSpecifier"];
	NSString *shortcut = groupSpecifier.name;
	HBLogDebug(@"Removing %@...", shortcut);
	if([[NSFileManager defaultManager] fileExistsAtPath:PATH_FOR_SHORTCUT(shortcut)]) {
		[[NSFileManager defaultManager] removeItemAtPath:PATH_FOR_SHORTCUT(shortcut) error:nil];
		triggerPreferencesReload();
	}
	for(PSSpecifier *iterationSpecifier in self.specifiers) {
		PSSpecifier *assignedGroupSpecifier = [iterationSpecifier propertyForKey:@"GroupSpecifier"];
		if(assignedGroupSpecifier == groupSpecifier) {
			[self removeSpecifier:iterationSpecifier animated:YES];
		}
	}
	[self removeSpecifier:groupSpecifier animated:YES];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
	HBLogDebug(@"Saving image for %@...", shortcutForImageSelection);
	if(shortcutForImageSelection != nil) {
		UIImage *image = (UIImage *) info[UIImagePickerControllerOriginalImage];
		[UIImageJPEGRepresentation(image, 1.f) writeToFile:PATH_FOR_SHORTCUT(shortcutForImageSelection) atomically:YES];
		[picker dismissViewControllerAnimated:YES completion:nil];
		HBLogDebug(@"Saved image for %@", shortcutForImageSelection);
		triggerPreferencesReload();
	}
	shortcutForImageSelection = nil;
}

@end
