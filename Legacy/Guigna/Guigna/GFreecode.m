#import "GFreecode.h"
#import "GAdditions.h"

@implementation GFreecode

- (instancetype)initWithAgent:(GAgent *)agent {
    self = [super initWithName:@"Freecode" agent:agent];
    if (self) {
        self.homepage = @"http://freshfoss.com/";
        self.itemsPerPage = 40;
        self.cmd = @"freecode";
    }
    return self;
}

// TODO:

- (void)refresh {
    NSMutableArray *projs = [NSMutableArray array];
    NSString *url = [NSString stringWithFormat:@"http://freshfoss.com/?n=%ld", self.pageNumber];
    // Don't use agent.nodesForUrl since NSXMLDocumentTidyHTML strips <article>
    NSMutableString *page = [NSMutableString stringWithContentsOfURL:[NSURL URLWithString:url] encoding:NSUTF8StringEncoding error:nil];
    [page replaceOccurrencesOfString:@"article" withString:@"div" options:0 range:NSMakeRange(0, [page length])];
    NSXMLDocument *xmlDoc = [[NSXMLDocument alloc] initWithXMLString:page options:NSXMLDocumentTidyHTML error:nil];
    NSArray *nodes = [[xmlDoc rootElement] nodesForXPath:@".//div[starts-with(@class,'project')]" error:nil];
    for (id node in nodes) {
        NSArray *titleNodes = node[@"h3/a/node()"];
        NSString *name = [titleNodes[0] stringValue];
        NSString *version = @"";
        if ([titleNodes count] > 2)
            version = [titleNodes[2] stringValue];
        NSString *ID = [[node[@"h3/a"][0] href] lastPathComponent];
        NSString *homepage = [node[@".//a[@itemprop='url']"][0] href];
        NSString *description = [node[@".//p[@itemprop='featureList']"][0] stringValue];
        NSArray *tagNodes = node[@".//p[@itemprop='keywords']/a"];
        NSMutableArray *tags = [NSMutableArray array];
        for (id node in tagNodes) {
            [tags addObject:[node stringValue]];
        }
        GItem *proj = [[GItem alloc] initWithName:name
                                          version:version
                                           source:self
                                           status:GAvailableStatus];
        proj.ID = ID;
        proj.license = tags[0];
        [tags removeObjectAtIndex:0];
        proj.categories = [tags join];
        proj.description = description;
        proj.homepage = homepage;
        [projs addObject:proj];
    }
    self.items = projs;
}

// TODO: parse log page
- (NSString *)home:(GItem *)item {
    return item.homepage;
}

- (NSString *)log:(GItem *)item {
    return [NSString stringWithFormat:@"http://freshfoss.com/projects/%@", item.ID];
}

@end
