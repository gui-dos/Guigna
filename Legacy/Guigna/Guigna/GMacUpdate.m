#import "GMacUpdate.h"
#import "GAdditions.h"

@implementation GMacUpdate

- (instancetype)initWithAgent:(GAgent *)agent {
    self = [super initWithName:@"MacUpdate" agent:agent];
    if (self) {
        self.homepage = @"http://www.macupdate.com";
        self.itemsPerPage = 80;
        self.cmd = @"macupdate";
    }
    return self;
}


- (void)refresh {
    NSMutableArray *entries = [NSMutableArray array];
    NSString *url = [NSString stringWithFormat:@"https://www.macupdate.com/page/%ld", self.pageNumber - 1];
    NSArray *nodes = [self.agent nodesForURL:url XPath:@"//tr[starts-with(@class,\"app_tr_row\")]"];
    for (id node in nodes) {
        NSString *name = [node[@".//a"][0] stringValue];
        NSUInteger idx = [name rindex:@" "];
        NSString *version = @"";
        if (idx != NSNotFound) {
            version = [name substringFromIndex:idx + 1];
            name = [name substringToIndex:idx];
        }
        NSString *description = [node[@".//span"][0] stringValue];
        NSString *price = [node[@".//span[contains(@class,\"appprice\")]"][0] stringValue];
        NSString *ID = [[node[@".//a"][0] href] split:@"/"][3];
        // NSString *category =
        GItem *entry = [[GItem alloc] initWithName:name
                                           version:version
                                            source:self
                                            status:GAvailableStatus];
        entry.ID = ID;
        // item.categories = category;
        if (![price is:@"Free"]) {
            description = [description stringByAppendingFormat:@" - $%@", price];
        } else {
            entry.license = @"Free";
        }
        entry.description = description;
        [entries addObject:entry];
    }
    self.items = entries;
}

- (NSString *)home:(GItem *)item {
    NSArray *nodes = [self.agent nodesForURL:[self log:item] XPath:@"//a[@target=\"devsite\"]"];
    // Old:
    // NSString *home = [[[[[nodes objectAtIndex:0] href] split:@"/"] objectAtIndex:3] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    // TODO: redirect
    NSString *home = [NSString stringWithFormat:@"http://www.macupdate.com%@", [[nodes[0] href] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    return home;
}

- (NSString *)log:(GItem *)item {
    return [NSString stringWithFormat:@"http://www.macupdate.com/app/mac/%@", item.ID];
}

@end
