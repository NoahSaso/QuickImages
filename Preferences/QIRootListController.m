#import "QIRootListController.h"
#import <Preferences/PSSpecifier.h>

#include <objc/runtime.h>
#include <notify.h>

#import "../Global.h"

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

	PSSpecifier *changeNameActionSpecifier = createButtonSpecifier(@"Change Trigger", controller, @selector(changeShortcutTrigger:));
	PSSpecifier *setImageActionSpecifier = createButtonSpecifier(@"Set Image", controller, @selector(setShortcutImage:));
	PSSpecifier *removeShortcutActionSpecifier = createButtonSpecifier(@"Remove Shortcut", controller, @selector(removeShortcut:));

	return @[groupSpecifier, changeNameActionSpecifier, setImageActionSpecifier, removeShortcutActionSpecifier];
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
		NSString *shortcut = alertController.textFields[0].text;
		HBLogDebug(@"Creating %@...", shortcut);
		[self addSpecifiersFromArray:createSpecifierArrayForShortcutWithController(shortcut, self) animated:YES];
		if(![[NSFileManager defaultManager] fileExistsAtPath:PATH_FOR_SHORTCUT(shortcut)]) {
			[[NSFileManager defaultManager] createFileAtPath:PATH_FOR_SHORTCUT(shortcut) contents:nil attributes:nil];
		}
		triggerPreferencesReload();
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler: ^(UIAlertAction *action) {
		HBLogDebug(@"Cancelled");
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

- (void)changeShortcutTrigger:(PSSpecifier *)specifier {
	NSString *shortcut = [self specifierAtIndex:([self indexOfSpecifier:specifier] - 1)].name;
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

- (void)setShortcutImage:(PSSpecifier *)specifier {
	NSString *shortcut = [self specifierAtIndex:([self indexOfSpecifier:specifier] - 2)].name;
	HBLogDebug(@"Changing image for %@...", shortcut);
}

- (void)removeShortcut:(PSSpecifier *)specifier {
	NSString *shortcut = [self specifierAtIndex:([self indexOfSpecifier:specifier] - 3)].name;
	HBLogDebug(@"Removing %@...", shortcut);
	if([[NSFileManager defaultManager] fileExistsAtPath:PATH_FOR_SHORTCUT(shortcut)]) {
		[[NSFileManager defaultManager] removeItemAtPath:PATH_FOR_SHORTCUT(shortcut) error:nil];
		triggerPreferencesReload();
	}
	[self removeSpecifierAtIndex:(self.specifiers.count - 1) animated:YES];
	[self removeSpecifierAtIndex:(self.specifiers.count - 1) animated:YES];
	[self removeSpecifierAtIndex:(self.specifiers.count - 1) animated:YES];
	[self removeSpecifierAtIndex:(self.specifiers.count - 1) animated:YES];
}

@end
