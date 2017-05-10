#define FIRE_DAB_PATH @"/User/Library/QuickImages/firedab.png"

@interface CKMessageEntryRichTextView : UITextView
@property (nonatomic, retain) NSMutableDictionary *composeImages;
- (void)paste:(id)arg1;
@end

%hook CKMessageEntryContentView

- (void)textViewDidChange:(CKMessageEntryRichTextView *)textView {
	%orig;
	if([[textView.text lowercaseString] containsString:@"bdab"]) {
		textView.text = [textView.text stringByReplacingOccurrencesOfString:@"bdab" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, textView.text.length)];
		UIImage *image = [UIImage imageWithContentsOfFile:FIRE_DAB_PATH];
		UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
		NSArray *items = pasteboard.items;
		[pasteboard setImage:image];
		[textView paste:nil];
		[pasteboard setItems:items];
	}
}

%end
