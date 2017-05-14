#import "Global.h"

static BOOL isEnabled = YES;
static NSArray *shortcuts = nil;

@interface CKMessageEntryRichTextView : UITextView
- (void)paste:(id)arg1;
@end

static NSString *getStringInStringFromArray(NSString *masterString, NSArray *array) {
	NSString *ret = nil;
	for(NSString *item in array) {
		if([masterString containsString:item]) {
			ret = item;
			break;
		}
	}
	return ret;
}

%hook CKMessageEntryContentView

- (void)textViewDidChange:(CKMessageEntryRichTextView *)textView {
	%orig;
	if(isEnabled) {
		NSString *shortcut = getStringInStringFromArray([textView.text lowercaseString], shortcuts);
		if(shortcut != nil) {
			NSString *imagePath = PATH_FOR_SHORTCUT(shortcut);
			if([[NSFileManager defaultManager] fileExistsAtPath:imagePath]) {
				UIImage *image = [UIImage imageWithContentsOfFile:imagePath];
				if(image != nil) {
					textView.text = [textView.text stringByReplacingOccurrencesOfString:shortcut withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, textView.text.length)];
					UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
					NSArray *originalItems = pasteboard.items;
					[pasteboard setImage:image];
					[textView paste:nil];
					[pasteboard setItems:originalItems];
				}
			}
		}
	}
}

%end

static void reloadPreferences() {
	CFPreferencesAppSynchronize(APP_ID);

	Boolean isEnabledExists = NO;
	Boolean isEnabledRef = CFPreferencesGetAppBooleanValue(CFSTR("Enabled"), APP_ID, &isEnabledExists);
	isEnabled = isEnabledExists ? isEnabledRef : YES;

	shortcuts = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:SHORTCUTS_PATH error:nil];
}

%ctor {
	reloadPreferences();
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL,
        (CFNotificationCallback)reloadPreferences,
        CFSTR("com.noahsaso.quickimages.pn"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
