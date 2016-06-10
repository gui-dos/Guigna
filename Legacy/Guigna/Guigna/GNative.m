#import "GNative.h"
#import "GAdditions.h"

@implementation GNative

- (instancetype)initWithAgent:(GAgent *)agent {
    self = [super initWithName:@"Native Installers" agent:agent];
    if (self) {
        self.homepage = @"http://github.com/gui-dos/Guigna/";
        self.itemsPerPage = 250;
        self.cmd = @"installer";
    }
    return self;
}

- (void) refresh {
    NSMutableArray *pkgs = [NSMutableArray array];
    NSString *url = @"https://docs.google.com/spreadsheets/d/1HOslVAaEwrcd7hmu6rWzd7jayMUT-nzaL9YL8llE35Q";
    NSArray *nodes = [self.agent nodesForURL:url XPath:@"//table[@class=\"waffle\"]//tr"];
    NSCharacterSet *whitespaceCharacterSet = [NSCharacterSet whitespaceCharacterSet];
    for (id node in nodes) {
        NSArray *columns = node[@"td[@dir=\"ltr\"]"];
        if ([columns count] == 0)
            continue;
        NSString *name = [[columns[0] stringValue] trim:whitespaceCharacterSet];
        if ([name is:@"Name"])
            continue;
        NSString *version = [[columns[1] stringValue] trim:whitespaceCharacterSet];
        NSString *homepage = [[columns[3] stringValue] trim:whitespaceCharacterSet];
        NSString *URL = [[columns[4] stringValue] trim:whitespaceCharacterSet];
        GItem *pkg = [[GItem alloc] initWithName:name
                                         version:version
                                          source:self
                                          status:GAvailableStatus];
        pkg.homepage = homepage;
        pkg.description = URL;
        pkg.URL = URL;
        [pkgs addObject:pkg];
    }
    self.items = pkgs;
}

@end
