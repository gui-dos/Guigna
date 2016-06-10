#import "GAppShopper.h"
#import "GAdditions.h"

@implementation GAppShopper

- (instancetype)initWithAgent:(GAgent *)agent {
    self = [super initWithName:@"AppShopper" agent:agent];
    if (self) {
        self.homepage = @"http://appshopper.com/mac/all/";
        self.itemsPerPage = 20;
        self.cmd = @"appstore";
    }
    return self;
}

- (void)refresh {
    NSMutableArray *apps = [NSMutableArray array];
    NSString *url = [NSString stringWithFormat:@"http://appshopper.com/mac/all/%ld", self.pageNumber];
    NSArray *nodes =[self.agent nodesForURL:url XPath:@"//div[@data-appid]"];
    NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
    NSCharacterSet *whitespaceAndNewlineCharacterSet = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    for (id node in nodes) {
        NSString *name = [node[@".//h2"][0] stringValue];
        name = [name trim:whitespaceAndNewlineCharacterSet];
        NSString *version = [node[@".//span[starts-with(@class,\"version\")]"][0] stringValue];
        version = [version substringFromIndex:2]; // trim "V "
        NSString *ID = node[@"@data-appid"];
        NSString *nick = [[node[@"a"][0] href] lastPathComponent];
        ID = [ID stringByAppendingFormat:@" %@", nick];
        NSString *category = [node[@".//h5/span"][0]stringValue];
        NSString *type = [node[@".//span[starts-with(@class,\"change\")]"][0] stringValue];
        NSString *description = [node[@".//p[@class=\"description\"]"][0]stringValue];
        NSString *price = [[node[@".//div[@class=\"price\"]"][0] children][0] stringValue];
        // TODO:NSXML UTF8 encoding
        NSMutableString *localPrice = [[price trim:whitespaceCharacterSet] mutableCopy];
        [localPrice replaceOccurrencesOfString:@"â‚¬" withString:@"€" options:0 range:NSMakeRange(0, [localPrice length])];
        GItem *app = [[GItem alloc] initWithName:name
                                         version:version
                                          source:self
                                          status:GAvailableStatus];
        app.ID = ID;
        app.categories = category;
        if (![localPrice is:@"Free"]) {
            description = [NSString stringWithFormat:@"%@ %@ - %@", type, localPrice, description];
        } else {
            description = [NSString stringWithFormat:@"%@ - %@", type, description];
            app.license = @"Free";
        }
        app.description = description;
        [apps addObject:app];
    }
    self.items = apps;
}

- (NSString *)home:(GItem *)item {
    id mainDiv =[self.agent nodesForURL:[@"http://itunes.apple.com/app/id" stringByAppendingString:[item.ID split][0]] XPath:@"//div[@id=\"main\"]"][0];
    NSArray *links = mainDiv[@"//div[@class=\"app-links\"]/a"];
    NSArray *screenshotsImgs = mainDiv[@"//div[contains(@class, \"screenshots\")]//img"];
    NSMutableString *screenshots = [NSMutableString string];
    NSInteger i = 0;
    for (id img in screenshotsImgs) {
        NSString *url = img[@"@src"];
        if (i > 0)
            [screenshots appendString:@" "];
        [screenshots appendString:url];
        i++;
    }
    item.screenshots = screenshots;
    NSString *homepage = [links[0] href];
    if ([homepage is:@"http://"])
        homepage = [links[1] href];
    return homepage;
}

- (NSString *)log:(GItem *)item {
    NSString *name = [item.ID split][1];
    NSString *category = [[item.categories replace:@" " with:@"-"] lowercaseString];
    category = [[category replace:@"-&-" with:@"-"] lowercaseString]; // fix Healthcare & Fitness
    return [NSString stringWithFormat:@"http://www.appshopper.com/mac/%@/%@", category, name];
}

@end
