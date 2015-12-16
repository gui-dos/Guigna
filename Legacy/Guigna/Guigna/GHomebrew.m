#import "GHomebrew.h"
#import "GPackage.h"
#import "GAdditions.h"

@implementation GHomebrew

+ (NSString *)prefix {
    return @"/usr/local";
}

- (instancetype)initWithAgent:(GAgent *)agent {
    self = [super initWithName:@"Homebrew" agent:agent];
    if (self) {
        self.homepage = @"http://brew.sh/";
        self.logpage = @"http://github.com/Homebrew/homebrew/commits";
        self.cmd = [NSString stringWithFormat:@"%@/bin/brew", self.prefix];
    }
    return self;
}

- (NSArray *)list {
    [self.index removeAllObjects];
    [self.items removeAllObjects];
    
    // /usr/bin/ruby -C /usr/local/Library/Homebrew -I. -e "require 'global'; require 'formula'; Formula.each {|f| puts \"#{f.name} #{f.pkg_version}\"}"
    
    NSMutableArray *output = [NSMutableArray arrayWithArray:[[self outputFor:@"/usr/bin/ruby -C %@/Library/Homebrew -I. -e require__'global';require__'formula';__Formula.each__{|f|__puts__\"#{f.full_name}|#{f.pkg_version}|#{f.bottle}|#{f.desc}\"}", self.prefix] split:@"\n"]];
    [output removeLastObject];
    for (NSString *line in output) {
        NSArray *components = [line split:@"|"];
        NSString *fullName = components[0];
        NSMutableArray *nameComponents = [NSMutableArray arrayWithArray:[fullName split:@"/"]];
        NSString *name = [nameComponents lastObject];
        [nameComponents removeLastObject];
        NSString *repo = nil;
        if ([nameComponents count] > 0) {
            repo = [nameComponents join:@"/"];
        }
        NSString *version = components[1];
        NSString *bottle = components[2];
        NSString *desc = components[3];
        GPackage *pkg = [[GPackage alloc] initWithName:name
                                               version:version
                                                system:self
                                                status:GAvailableStatus];
        if (![bottle is:@""])
            desc = [@"🍶" stringByAppendingString:desc];
        if (![desc is:@""])
            pkg.description = desc;
        if (repo != nil) {
            pkg.categories = [repo lastPathComponent];
            pkg.repo = repo;
        }
        [self.items addObject:pkg];
        self[name] = pkg;
    }
    
    // TODO
    if ([[self defaults:@"HomebrewMainTaps"] isEqual:@YES]) {
        BOOL brewCaskCommandAvailable = [[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Library/Taps/caskroom/homebrew-cask/cmd/brew-cask.rb", self.prefix]];
        output = [NSMutableArray arrayWithArray:[[self outputFor:@"%@ search \"\"", self.cmd] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
        for (NSString *line in output) {
            if (![line contains:@"/"])
                continue;
            NSArray *tokens = [line split:@"/"];
            NSString *name = tokens[[tokens count]-1];
            if ([tokens[1] is:@"cask"] && brewCaskCommandAvailable)
                continue;
            if (self[name] != nil)
                continue;
            NSString *repo = [NSString stringWithFormat:@"%@/%@", tokens[0], tokens[1]];
            GPackage *pkg = [[GPackage alloc] initWithName:name
                                                   version:@""
                                                    system:self
                                                    status:GAvailableStatus];
            pkg.categories = tokens[1];
            pkg.repo = repo;
            pkg.description = repo;
            [self.items addObject:pkg];
            self[name] = pkg;
        }
    }
    
    [self installed]; // update status
    return self.items;
}


- (NSArray *)installed {
    if (self.isHidden)
        return [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status != %@", @(GAvailableStatus)]];
    NSMutableArray *pkgs = [NSMutableArray array];
    if (self.mode == GOnlineMode)
        return pkgs;
    NSMutableArray *output = [NSMutableArray arrayWithArray:[[self outputFor:@"%@ list --versions", self.cmd] split:@"\n"]];
    [output removeLastObject];
    GStatus status;
    NSArray *inactive = [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == %@", @(GInactiveStatus)]];
    [self.items removeObjectsInArray:inactive];
    [self.agent.appDelegate.allPackages removeObjectsInArray:inactive]; // TODO: ugly
    for (GPackage *pkg in self.items) {
        status = pkg.status;
        pkg.installed = nil;
        if (status != GUpdatedStatus && status != GNewStatus)
            pkg.status = GAvailableStatus;
    }
    [self outdated]; // update status
    NSString *name;
    NSString *version;
    for (NSString *line in output) {
        NSMutableArray *components = [[line split] mutableCopy];
        name = components[0];
        if ([name is:@"Error:"])
            return pkgs;
        [components removeObjectAtIndex:0];
        NSUInteger versionCount = [components count];
        version = [components lastObject];
        GPackage *pkg = self[name];
        NSString *latestVersion = (pkg == nil) ? nil : [pkg.version copy];
        if (versionCount > 1) {
            for (NSInteger i = 0; i < versionCount - 1; i++) {
                GPackage *inactivePkg = [[GPackage alloc] initWithName:name
                                                               version:latestVersion
                                                                system:self
                                                                status:GInactiveStatus];
                inactivePkg.installed = components[i];
                [self.items addObject:inactivePkg];
                [self.agent.appDelegate.allPackages addObject:inactivePkg]; // TODO: ugly
                [pkgs addObject:inactivePkg];
            }
        }
        if (pkg == nil) {
            pkg = [[GPackage alloc] initWithName:name
                                         version:latestVersion
                                          system:self
                                          status:GUpToDateStatus];
            self[name] = pkg;
        } else {
            if (pkg.status == GAvailableStatus) {
                pkg.status = GUpToDateStatus;
            }
        }
        pkg.installed = version;
        [pkgs addObject:pkg];
    }
    return pkgs;
}

- (NSArray *)outdated {
    if (self.isHidden)
        return [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == %@", @(GOutdatedStatus)]];
    NSMutableArray *pkgs = [NSMutableArray array];
    if (self.mode == GOnlineMode)
        return pkgs;
    NSMutableArray *output = [NSMutableArray arrayWithArray:[[self outputFor:@"%@ outdated", self.cmd] split:@"\n"]];
    [output removeLastObject];
    for (NSString *line in output) {
        NSArray *components = [line split];
        NSString *name = components[0];
        if ([name is:@"Error:"])
            return pkgs;
        if ([name contains:@"/"])
            name = [name lastPathComponent];
        GPackage *pkg = self[name];
        NSString *latestVersion = (pkg == nil) ? nil : [pkg.version copy];
        // NSString *version = components[1]; // TODO: strangely, output contains only name
        NSString *version = (pkg == nil) ? @"..." : [pkg.installed copy];
        if (pkg == nil) {
            pkg = [[GPackage alloc] initWithName:name
                                         version:latestVersion
                                          system:self
                                          status:GOutdatedStatus];
            self[name] = pkg;
        } else
            pkg.status = GOutdatedStatus;
        pkg.installed = version;
        [pkgs addObject:pkg];
    }
    return pkgs;
}

- (NSArray *)inactive {
    if (self.isHidden)
        return [self.items filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"status == %@", @(GInactiveStatus)]];
    NSMutableArray *pkgs = [NSMutableArray array];
    if (self.mode == GOnlineMode)
        return pkgs;
    for (GPackage *pkg in [self installed]) {
        if (pkg.status == GInactiveStatus)
            [pkgs addObject:pkg];
    }
    return pkgs;
}


- (NSString *)info:(GItem *)item {
    if (!self.isHidden)
        return [self outputFor:@"%@ info %@", self.cmd, item.name];
    else
        return [super info:item];
}

- (NSString *)home:(GItem *)item {
    NSString *page;
    if (self.isHidden) {
        for (NSString *line in [[self cat:item] split:@"\n"]) {
            NSUInteger idx = [line index:@"homepage"];
            if (idx != NSNotFound) {
                page = [[line substringFromIndex:idx + 8] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([page contains:@"http"])
                    return [page stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"'\""]];
            }
        }
    } else {
        NSArray *outputLines = [[self outputFor:@"%@ info %@", self.cmd, item.name] split:@"\n"];
        page = outputLines[2];
        if (![page hasPrefix:@"http"]) {  // desc line is missing
            page = outputLines[1];
        }
        return page;
    }
    return [self log:item];
}

- (NSString *)log:(GItem *)item {
    NSString *path;
    if (((GPackage *)item).repo == nil)
        path = @"Homebrew/homebrew/commits/master/Library/Formula";
    else {
        NSArray *tokens = [((GPackage *)item).repo split:@"/"];
        NSString *user = tokens[0];
        path = [NSString stringWithFormat:@"%@/homebrew-%@/commits/master", user, tokens[1]];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/Library/Taps/%@/homebrew-%@/Formula", self.prefix, user, tokens[1]]]) {
            path = [path stringByAppendingString:@"/Formula"];
        }
    }
    return [NSString stringWithFormat:@"http://github.com/%@/%@.rb", path, item.name];
    
}

- (NSString *)contents:(GItem *)item {
    if (!self.isHidden)
        return [self outputFor:@"%@ list -v %@", self.cmd, item.name];
    else
        return @"";
}

- (NSString *)cat:(GItem *)item {
    if (!self.isHidden)
        return [self outputFor:@"%@ cat %@", self.cmd, item.name];
    else {
        return [NSString stringWithContentsOfFile:[self.prefix stringByAppendingFormat:@"_off/Library/Formula/%@.rb", item.name] encoding:NSUTF8StringEncoding error: nil];
    }
}

- (NSString *)deps:(GItem *)item {
    if (!self.isHidden)
        return [self outputFor:@"%@ deps -n %@", self.cmd, item.name];
    else
        return @"[Cannot compute the dependencies now]";
}

- (NSString *)dependents:(GItem *)item {
    if (!self.isHidden)
        return [self outputFor:@"%@ uses --installed %@", self.cmd, item.name];
    else
        return @"";
}

- (NSString *)options:(GPackage *)pkg {
    NSString *options = nil;
    NSMutableArray *output = [NSMutableArray arrayWithArray:[[self outputFor:[NSString stringWithFormat:@"%@ options %@", self.cmd, pkg.name]] split:@"\n"]];
    if ([output count] > 1 ) {
        NSArray * optionLines = [output filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH '--'"]];
        options = [[optionLines join] replace:@"--" with:@""];
    }
    return options;
}


- (NSArray *)availableCommands {
    return [super availableCommands];
}


- (NSString *) installCmd:(GPackage *)pkg {
    NSString *options = pkg.markedOptions;
    if (options == nil)
        options = @"";
    else
        options = [@"--" stringByAppendingString:[options replace:@" " with:@" --"]];
    
    return [NSString stringWithFormat:@"%@ install %@ %@", self.cmd, options, pkg.name];
}

- (NSString *) uninstallCmd:(GPackage *)pkg {
    if (pkg.status == GInactiveStatus)
        return [self cleanCmd:pkg];
    else  // TODO: manage --force flag
        return [NSString stringWithFormat:@"%@ remove --force %@", self.cmd, pkg.name];
}

- (NSString *) upgradeCmd:(GPackage *)pkg {
    return [NSString stringWithFormat:@"%@ upgrade %@", self.cmd, pkg.name];
    
}

- (NSString *)cleanCmd:(GPackage *)pkg {
    return [NSString stringWithFormat:@"%@ cleanup --force %@ &>/dev/null ; rm -f /Library/Caches/Homebrew/%@-%@*bottle*", self.cmd, pkg.name, pkg.name, pkg.installed];
}

- (NSString *)updateCmd {
    return [NSString stringWithFormat:@"%@ update", self.cmd];
}

- (NSString *)hideCmd {
    return [NSString stringWithFormat:@"sudo mv %@ %@_off", self.prefix, self.prefix];
}

- (NSString *)unhideCmd {
    return [NSString stringWithFormat:@"sudo mv %@_off %@", self.prefix, self.prefix];
}

+ (NSString *)setupCmd {
    return @"ruby -e \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)\" ; /usr/local/bin/brew update";
}

+ (NSString *)removeCmd {
    return @"cd /usr/local ; curl -L https://raw.github.com/gist/1173223 -o uninstall_homebrew.sh; sudo sh uninstall_homebrew.sh ; rm uninstall_homebrew.sh ; sudo rm -rf /Library/Caches/Homebrew; rm -rf /usr/local/.git";
}

- (NSString *)verbosifiedCmd:(NSString *)cmd {
    NSMutableArray *tokens = [[cmd split] mutableCopy];
    [tokens insertObject:@"-v" atIndex:2];
    return [tokens join];
}

@end
